import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../models/place_models.dart';
import 'backend.dart';

class PlacesWebBackend implements PlacesBackend {
  PlacesWebBackend({required this.apiKey, this.timeZoneBaseUrl})
    : _httpClient = BrowserClient();

  static const _mapsScriptId = 'google_places_autocomplete_maps_js';
  static const _defaultTimeZoneBaseUrl =
      'https://maps.googleapis.com/maps/api/timezone/json';

  final String apiKey;
  final String? timeZoneBaseUrl;
  final http.Client _httpClient;
  final Map<String, Object> _sessionTokens = <String, Object>{};

  static Completer<Object>? _placesLibraryCompleter;
  static String? _loadedApiKey;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request,
  ) async {
    final library = await _loadPlacesLibrary();
    final autocompleteSuggestion =
        library.getProperty('AutocompleteSuggestion'.toJS) as JSFunction;
    final fetchSuggestions =
        autocompleteSuggestion.getProperty('fetchAutocompleteSuggestions'.toJS)
            as JSFunction;
    final result =
        await (fetchSuggestions.callAsFunction(
                  autocompleteSuggestion,
                  _jsifyAutocompleteRequest(request, library: library),
                )
                as JSPromise<JSAny?>)
            .toDart;
    final suggestions =
        (result as JSObject).getProperty('suggestions'.toJS) as JSObject;
    final length =
        (suggestions.getProperty('length'.toJS) as JSNumber).toDartInt;
    final items = <PlaceSuggestion>[];
    for (var index = 0; index < length; index++) {
      final suggestion = suggestions.getProperty(index.toJS) as JSObject;
      final prediction = suggestion.getProperty('placePrediction'.toJS);
      if (prediction == null) {
        continue;
      }
      items.add(_predictionToSuggestion(prediction as JSObject));
    }
    return items;
  }

  @override
  Future<PlaceData> fetchPlace(PlaceDetailsRequest request) async {
    final library = await _loadPlacesLibrary();
    final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
    final place = placeCtor.callAsConstructor<JSObject>(
      <String, Object?>{
            'id': request.placeId,
            if (request.languageCode != null)
              'requestedLanguage': request.languageCode,
            if (request.regionCode != null)
              'requestedRegion': request.regionCode,
          }.jsify()!
          as JSObject,
    );

    final fetchFields = place.getProperty('fetchFields'.toJS) as JSFunction;
    await (fetchFields.callAsFunction(
              place,
              <String, Object?>{
                'fields': request.fields.map((field) => field.apiName).toList(),
              }.jsify()!,
            )
            as JSPromise<JSAny?>)
        .toDart;

    return PlaceData.fromJson(_extractPlaceMap(place, request.fields));
  }

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(TimeZoneRequest request) async {
    final timestamp = request.timestamp?.toUtc() ?? DateTime.now().toUtc();
    final uri =
        Uri.parse(
          _normalizeTimeZoneUrl(timeZoneBaseUrl ?? _defaultTimeZoneBaseUrl),
        ).replace(
          queryParameters: <String, String>{
            'location':
                '${request.location.latitude},${request.location.longitude}',
            'timestamp': (timestamp.millisecondsSinceEpoch ~/ 1000).toString(),
            'key': apiKey,
            if (request.languageCode != null) 'language': request.languageCode!,
          },
        );
    final response = await _httpClient.get(uri);
    final dynamic decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    final body = (decoded as Map).cast<String, Object?>();
    if (response.statusCode >= 400) {
      throw PlacesException(
        'Google Time Zone request failed.',
        statusCode: response.statusCode,
        details: body,
      );
    }
    final status = (body['status'] ?? 'UNKNOWN_ERROR') as String;
    if (status != 'OK') {
      throw PlacesException(
        (body['errorMessage'] ?? 'Google Time Zone request failed.') as String,
        statusCode: response.statusCode,
        details: body,
      );
    }
    return PlaceTimeZoneData.fromJson(body, timestamp: timestamp);
  }

  @override
  Future<List<PlaceData>> searchText(TextSearchRequest request) async {
    final library = await _loadPlacesLibrary();
    final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
    final requestMap = <String, Object?>{
      'textQuery': request.textQuery,
      'fields': request.fields.map((field) => field.apiName).toList(),
      if (request.languageCode != null) 'language': request.languageCode,
      if (request.regionCode != null) 'region': request.regionCode,
      if (request.includedType != null) 'includedType': request.includedType,
      if (request.strictTypeFiltering) 'strictTypeFiltering': true,
      if (request.locationBias != null)
        'locationBias': request.locationBias!.area.toWebJson(),
      if (request.locationRestriction != null)
        'locationRestriction': request.locationRestriction!.area.toWebJson(),
      if (request.maxResultCount != null)
        'maxResultCount': request.maxResultCount,
      if (request.minRating != null) 'minRating': request.minRating,
      if (request.openNow != null) 'openNow': request.openNow,
      'rankPreference': _searchByTextRankPreference(
        library,
        request.rankPreference,
      ),
    };

    final searchByText =
        placeCtor.getProperty('searchByText'.toJS) as JSFunction;
    final result =
        await (searchByText.callAsFunction(placeCtor, requestMap.jsify()!)
                as JSPromise<JSAny?>)
            .toDart;

    return _extractPlaceResults(
      result: result as JSObject,
      fields: request.fields,
    );
  }

  @override
  Future<List<PlaceData>> searchNearby(NearbySearchRequest request) async {
    final library = await _loadPlacesLibrary();
    final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
    final requestMap = <String, Object?>{
      'fields': request.fields.map((field) => field.apiName).toList(),
      'locationRestriction': request.locationRestriction.area.toWebJson(),
      if (request.languageCode != null) 'language': request.languageCode,
      if (request.regionCode != null) 'region': request.regionCode,
      if (request.includedTypes.isNotEmpty)
        'includedTypes': request.includedTypes,
      if (request.excludedTypes.isNotEmpty)
        'excludedTypes': request.excludedTypes,
      if (request.includedPrimaryTypes.isNotEmpty)
        'includedPrimaryTypes': request.includedPrimaryTypes,
      if (request.excludedPrimaryTypes.isNotEmpty)
        'excludedPrimaryTypes': request.excludedPrimaryTypes,
      if (request.maxResultCount != null)
        'maxResultCount': request.maxResultCount,
      'rankPreference': _searchNearbyRankPreference(
        library,
        request.rankPreference,
      ),
    };

    final searchNearby =
        placeCtor.getProperty('searchNearby'.toJS) as JSFunction;
    final result =
        await (searchNearby.callAsFunction(placeCtor, requestMap.jsify()!)
                as JSPromise<JSAny?>)
            .toDart;

    return _extractPlaceResults(
      result: result as JSObject,
      fields: request.fields,
    );
  }

  @override
  Future<void> close() async {
    _httpClient.close();
  }

  Future<JSObject> _loadPlacesLibrary() async {
    if (_placesLibraryCompleter != null) {
      return _placesLibraryCompleter!.future as Future<JSObject>;
    }
    _placesLibraryCompleter = Completer<Object>();
    try {
      if (_loadedApiKey != null && _loadedApiKey != apiKey) {
        throw PlacesException(
          'Google Maps JavaScript API is already loaded with a different API key.',
        );
      }
      if (!_hasGoogleMapsImportLibrary()) {
        await _injectMapsScript();
      }
      _loadedApiKey = apiKey;
      final google = web.window.getProperty('google'.toJS) as JSObject;
      final maps = google.getProperty('maps'.toJS) as JSObject;
      final importLibrary =
          maps.getProperty('importLibrary'.toJS) as JSFunction;
      final library =
          await (importLibrary.callAsFunction(maps, 'places'.toJS)
                  as JSPromise<JSAny?>)
              .toDart;
      _placesLibraryCompleter!.complete(library);
    } catch (error, stackTrace) {
      _placesLibraryCompleter!.completeError(error, stackTrace);
    }
    return _placesLibraryCompleter!.future as Future<JSObject>;
  }

  bool _hasGoogleMapsImportLibrary() {
    if (!web.window.has('google')) {
      return false;
    }
    final google = web.window.getProperty('google'.toJS) as JSObject;
    if (!google.has('maps')) {
      return false;
    }
    final maps = google.getProperty('maps'.toJS) as JSObject;
    return maps.has('importLibrary');
  }

  Future<void> _injectMapsScript() async {
    final existing = web.document.getElementById(_mapsScriptId);
    if (existing != null) {
      await (existing as web.HTMLScriptElement).onLoad.first;
      return;
    }
    final script = web.HTMLScriptElement()
      ..id = _mapsScriptId
      ..async = true
      ..src =
          'https://maps.googleapis.com/maps/api/js'
          '?key=$apiKey&loading=async&libraries=places&v=weekly';
    final load = script.onLoad.first;
    final error = script.onError.first.then<void>(
      (_) => throw const PlacesException(
        'Failed to load the Google Maps JavaScript Places library.',
      ),
    );
    web.document.head!.append(script);
    await Future.any(<Future<void>>[load, error]);
  }

  JSObject _jsifyAutocompleteRequest(
    AutocompleteRequest request, {
    required JSObject library,
  }) {
    request.validate();
    return <String, Object?>{
          'input': request.input,
          if (request.languageCode != null) 'language': request.languageCode,
          if (request.regionCode != null) 'region': request.regionCode,
          if (request.inputOffset != null) 'inputOffset': request.inputOffset,
          if (request.origin != null) 'origin': request.origin!.toWebJson(),
          if (request.locationBias != null)
            'locationBias': request.locationBias!.area.toWebJson(),
          if (request.locationRestriction != null)
            'locationRestriction': request.locationRestriction!.area
                .toWebJson(),
          if (request.includedPrimaryTypes.isNotEmpty)
            'includedPrimaryTypes': request.includedPrimaryTypes,
          if (request.includedRegionCodes.isNotEmpty)
            'includedRegionCodes': request.includedRegionCodes,
          if (request.includePureServiceAreaBusinesses)
            'includePureServiceAreaBusinesses': true,
          if (request.sessionToken != null)
            'sessionToken': _sessionTokenFor(
              request.sessionToken!,
              library: library,
            ),
        }.jsify()!
        as JSObject;
  }

  JSObject _sessionTokenFor(
    AutocompleteSessionToken token, {
    required JSObject library,
  }) {
    final cached = _sessionTokens[token.value];
    if (cached != null) {
      return cached as JSObject;
    }
    final tokenCtor =
        library.getProperty('AutocompleteSessionToken'.toJS) as JSFunction;
    final value = tokenCtor.callAsConstructor<JSObject>();
    _sessionTokens[token.value] = value;
    return value;
  }

  PlaceSuggestion _predictionToSuggestion(JSObject prediction) {
    final text = prediction.getProperty('text'.toJS);
    final structuredFormat = prediction.getProperty('structuredFormat'.toJS);
    final types = _listOfStrings(prediction.getProperty('types'.toJS));

    return PlaceSuggestion(
      placeId:
          ((prediction.getProperty('placeId'.toJS) as JSString?)?.toDart) ?? '',
      placeResourceName:
          ((prediction.getProperty('place'.toJS) as JSString?)?.toDart) ?? '',
      fullText: StructuredText.fromJson(_dartify(text)),
      primaryText: StructuredText.fromJson(
        structuredFormat == null
            ? _dartify(text)
            : _dartify(
                (structuredFormat as JSObject).getProperty('mainText'.toJS) ??
                    text,
              ),
      ),
      secondaryText: structuredFormat == null
          ? null
          : StructuredText.fromJson(
              _dartify(
                (structuredFormat as JSObject).getProperty(
                  'secondaryText'.toJS,
                ),
              ),
            ),
      distanceMeters:
          (prediction.getProperty('distanceMeters'.toJS) as JSNumber?)
              ?.toDartInt,
      types: types,
      rawData:
          _dartify(prediction as JSAny?) as Map<String, Object?>? ??
          <String, Object?>{
            'placeId':
                ((prediction.getProperty('placeId'.toJS) as JSString?)?.toDart),
            'place':
                ((prediction.getProperty('place'.toJS) as JSString?)?.toDart),
          },
    );
  }

  List<PlaceData> _extractPlaceResults({
    required JSObject result,
    required Set<PlaceField> fields,
  }) {
    final places = result.getProperty('places'.toJS) as JSObject;
    final length = (places.getProperty('length'.toJS) as JSNumber).toDartInt;
    final items = <PlaceData>[];
    for (var index = 0; index < length; index++) {
      final place = places.getProperty(index.toJS) as JSObject;
      items.add(PlaceData.fromJson(_extractPlaceMap(place, fields)));
    }
    return items;
  }

  Map<String, Object?> _extractPlaceMap(
    JSObject place,
    Set<PlaceField> fields,
  ) {
    final data = <String, Object?>{};
    for (final field in fields) {
      final value = _fieldValue(place, field.apiName);
      if (value != null) {
        data[field.apiName] = value;
      }
    }
    final id = _fieldValue(place, 'id');
    if (id != null) {
      data['id'] = id;
    }
    final name = _fieldValue(place, 'name');
    if (name != null) {
      data['name'] = name;
    }
    return data;
  }

  Object? _fieldValue(JSObject place, String fieldName) {
    if (!place.has(fieldName)) {
      return null;
    }
    return _dartify(place.getProperty(fieldName.toJS));
  }

  Object? _dartify(JSAny? value) {
    if (value == null) {
      return null;
    }
    if (value.isA<JSString>()) {
      return (value as JSString).toDart;
    }
    if (value.isA<JSNumber>()) {
      final number = (value as JSNumber).toDartDouble;
      if (number == number.roundToDouble()) {
        return number.toInt();
      }
      return number;
    }
    if (value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart;
    }
    if (value.isA<JSObject>() &&
        _hasMethod(value as JSObject, 'lat') &&
        _hasMethod(value, 'lng')) {
      return <String, Object?>{
        'latitude':
            ((value.getProperty('lat'.toJS) as JSFunction).callAsFunction(value)
                    as JSNumber)
                .toDartDouble,
        'longitude':
            ((value.getProperty('lng'.toJS) as JSFunction).callAsFunction(value)
                    as JSNumber)
                .toDartDouble,
      };
    }
    if (value.isA<JSObject>() && _hasMethod(value as JSObject, 'toJSON')) {
      return _dartify(
        (value.getProperty('toJSON'.toJS) as JSFunction).callAsFunction(value),
      );
    }
    try {
      final dartified = value.dartify();
      if (dartified is Map) {
        return dartified.cast<String, Object?>();
      }
      if (dartified is List) {
        return dartified.cast<Object?>();
      }
      return dartified;
    } catch (_) {
      return null;
    }
  }

  bool _hasMethod(JSObject value, String property) => value.has(property);

  List<String> _listOfStrings(JSAny? value) {
    if (value == null) {
      return const <String>[];
    }
    final dartified = _dartify(value);
    if (dartified is List) {
      return dartified.whereType<String>().toList(growable: false);
    }
    return const <String>[];
  }

  JSAny _searchByTextRankPreference(
    JSObject library,
    SearchByTextRankPreference preference,
  ) {
    final values =
        library.getProperty('SearchByTextRankPreference'.toJS) as JSObject;
    return values.getProperty(preference.name.toUpperCase().toJS)!;
  }

  JSAny _searchNearbyRankPreference(
    JSObject library,
    SearchNearbyRankPreference preference,
  ) {
    final values =
        library.getProperty('SearchNearbyRankPreference'.toJS) as JSObject;
    return values.getProperty(preference.name.toUpperCase().toJS)!;
  }
}

String _normalizeTimeZoneUrl(String value) {
  final normalized = value.endsWith('/')
      ? value.substring(0, value.length - 1)
      : value;
  return normalized.endsWith('/json') ? normalized : '$normalized/json';
}
