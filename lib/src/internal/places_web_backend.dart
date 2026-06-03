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
  PlacesWebBackend({
    required this.apiKey,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
  }) : _httpClient = BrowserClient();

  static const _mapsScriptId = 'google_places_sdk_flutter_maps_js';
  static const _defaultPlacesBaseUrl = 'https://places.googleapis.com/v1';
  static const _defaultTimeZoneBaseUrl =
      'https://maps.googleapis.com/maps/api/timezone/json';

  final String apiKey;
  final String? proxyBaseUrl;
  final String? timeZoneBaseUrl;
  final http.Client _httpClient;
  final Map<String, Object> _sessionTokens = <String, Object>{};

  static Completer<JSObject>? _placesLibraryCompleter;
  static String? _loadedApiKey;

  String get _placesBaseUrl => proxyBaseUrl ?? _defaultPlacesBaseUrl;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request,
  ) async {
    final suggestions = await autocompleteSuggestions(request);
    return suggestions.whereType<PlaceSuggestion>().toList(growable: false);
  }

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
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
    final items = <AutocompleteSuggestion>[];
    for (var index = 0; index < length; index++) {
      final suggestion = suggestions.getProperty(index.toJS) as JSObject;
      final prediction = suggestion.getProperty('placePrediction'.toJS);
      if (prediction != null) {
        items.add(_predictionToSuggestion(prediction as JSObject));
        continue;
      }
      final queryPrediction = suggestion.getProperty('queryPrediction'.toJS);
      if (queryPrediction != null) {
        items.add(_queryPredictionToSuggestion(queryPrediction as JSObject));
      }
    }
    return items;
  }

  @override
  Future<PlaceData> fetchPlace(PlaceDetailsRequest request) async {
    try {
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
                  'fields': request.fields.map(_webFieldName).toList(),
                }.jsify()!,
              )
              as JSPromise<JSAny?>)
          .toDart;

      return PlaceData.fromJson(_extractPlaceMap(place, request.fields));
    } catch (error) {
      if (!_shouldFallbackToHttp(error)) {
        rethrow;
      }
      return _fetchPlaceOverHttp(request);
    }
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(PhotoMediaRequest request) async {
    final response = await _get(
      path: request.mediaPath,
      queryParameters: <String, String>{
        ...request.toQueryParameters(),
        'key': apiKey,
      },
    );
    return PlacePhotoMedia.fromJson(response);
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
    final body = (decoded as Map<Object?, Object?>).cast<String, Object?>();
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
    try {
      final library = await _loadPlacesLibrary();
      final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
      final requestMap = <String, Object?>{
        'textQuery': request.textQuery,
        'fields': request.fields.map(_webFieldName).toList(),
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
    } catch (error) {
      if (!_shouldFallbackToHttp(error)) {
        rethrow;
      }
      return _searchTextOverHttp(request);
    }
  }

  @override
  Future<List<PlaceData>> searchNearby(NearbySearchRequest request) async {
    try {
      final library = await _loadPlacesLibrary();
      final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
      final requestMap = <String, Object?>{
        'fields': request.fields.map(_webFieldName).toList(),
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
    } catch (error) {
      if (!_shouldFallbackToHttp(error)) {
        rethrow;
      }
      return _searchNearbyOverHttp(request);
    }
  }

  @override
  Future<void> close() async {
    _httpClient.close();
  }

  Future<JSObject> _loadPlacesLibrary() async {
    if (_placesLibraryCompleter != null) {
      return _placesLibraryCompleter!.future;
    }
    _placesLibraryCompleter = Completer<JSObject>();
    try {
      if (_loadedApiKey != null && _loadedApiKey != apiKey) {
        throw PlacesException(
          'Google Maps JavaScript API is already loaded with a different API key.',
        );
      }
      if (!_hasGoogleMapsImportLibrary()) {
        await _injectMapsScript();
      }
      await _waitForImportLibrary();
      _loadedApiKey = apiKey;
      final google = web.window.getProperty('google'.toJS) as JSObject;
      final maps = google.getProperty('maps'.toJS) as JSObject;
      final importLibrary =
          maps.getProperty('importLibrary'.toJS) as JSFunction;
      final library =
          await (importLibrary.callAsFunction(maps, 'places'.toJS)
                  as JSPromise<JSAny?>)
              .toDart;
      _placesLibraryCompleter!.complete(library as JSObject);
    } catch (error, stackTrace) {
      _placesLibraryCompleter!.completeError(error, stackTrace);
    }
    return _placesLibraryCompleter!.future;
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

  Future<void> _waitForImportLibrary() async {
    const maxAttempts = 50;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (_hasGoogleMapsImportLibrary()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw const PlacesException(
      'Google Maps JavaScript Places library did not finish initializing.',
    );
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
          if (request.includeQueryPredictions) 'includeQueryPredictions': true,
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
      fullText: _structuredTextFromJs(text),
      primaryText: _structuredTextFromJs(
        structuredFormat == null
            ? text
            : (structuredFormat as JSObject).getProperty('mainText'.toJS) ??
                  text,
      ),
      secondaryText: structuredFormat == null
          ? null
          : _structuredTextFromJs(
              (structuredFormat as JSObject).getProperty('secondaryText'.toJS),
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

  QuerySuggestion _queryPredictionToSuggestion(JSObject prediction) {
    final text = _structuredTextFromJs(prediction.getProperty('text'.toJS));
    return QuerySuggestion(
      fullText: text,
      matches: text.matches,
      rawData:
          _dartify(prediction as JSAny?) as Map<String, Object?>? ??
          <String, Object?>{'text': text.text},
    );
  }

  StructuredText _structuredTextFromJs(JSAny? value) {
    if (value == null) {
      return const StructuredText(text: '');
    }
    if (value.isA<JSString>()) {
      return StructuredText(text: (value as JSString).toDart);
    }
    if (!value.isA<JSObject>()) {
      return StructuredText.fromJson(_dartify(value));
    }

    final object = value as JSObject;
    final text = ((object.getProperty('text'.toJS) as JSString?)?.toDart) ?? '';
    final matchesValue = object.getProperty('matches'.toJS);
    final matches = <TextMatch>[];

    if (matchesValue != null && matchesValue.isA<JSObject>()) {
      final jsMatches = matchesValue as JSObject;
      final length =
          (jsMatches.getProperty('length'.toJS) as JSNumber?)?.toDartInt ?? 0;
      for (var index = 0; index < length; index++) {
        final entry = jsMatches.getProperty(index.toJS);
        if (entry == null || !entry.isA<JSObject>()) {
          continue;
        }
        final match = entry as JSObject;
        final startOffset =
            (match.getProperty('startOffset'.toJS) as JSNumber?)?.toDartInt ??
            0;
        final endOffset =
            (match.getProperty('endOffset'.toJS) as JSNumber?)?.toDartInt ??
            (startOffset + 1);
        matches.add(TextMatch(startOffset: startOffset, endOffset: endOffset));
      }
    }

    return StructuredText(text: text, matches: matches);
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
      final value = _fieldValue(place, _webFieldName(field));
      if (value != null) {
        data[field.apiName] = _normalizeWebFieldValue(field, value);
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
    if (value.isA<JSObject>()) {
      final jsonValue = _jsonDecodeJsValue(value as JSObject);
      if (jsonValue != null) {
        return jsonValue;
      }
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

  Object? _jsonDecodeJsValue(JSObject value) {
    try {
      final json = web.window.getProperty('JSON'.toJS) as JSObject;
      final stringify = json.getProperty('stringify'.toJS) as JSFunction?;
      if (stringify == null) {
        return null;
      }
      final encoded = stringify.callAsFunction(json, value);
      if (encoded == null || !encoded.isA<JSString>()) {
        return null;
      }
      final decoded = jsonDecode((encoded as JSString).toDart);
      if (decoded is Map) {
        return decoded.cast<String, Object?>();
      }
      if (decoded is List) {
        return decoded.cast<Object?>();
      }
      return decoded;
    } catch (_) {
      return null;
    }
  }

  bool _hasMethod(JSObject value, String property) => value.has(property);

  bool _shouldFallbackToHttp(Object error) {
    final message = error.toString();
    return message.contains('Unknown fields requested') ||
        message.contains('InvalidValueError: in property fields');
  }

  Future<PlaceData> _fetchPlaceOverHttp(PlaceDetailsRequest request) async {
    final path = request.placeId.startsWith('places/')
        ? request.placeId
        : 'places/${Uri.encodeComponent(request.placeId)}';
    final response = await _get(
      path: path,
      fieldMask: request.detailsFieldMask,
      queryParameters: <String, String>{
        if (request.languageCode != null) 'languageCode': request.languageCode!,
        if (request.regionCode != null) 'regionCode': request.regionCode!,
        if (request.sessionToken != null)
          'sessionToken': request.sessionToken!.value,
      },
    );
    return PlaceData.fromJson(response);
  }

  Future<List<PlaceData>> _searchTextOverHttp(TextSearchRequest request) async {
    final response = await _post(
      path: 'places:searchText',
      body: request.toRestJson(),
      fieldMask: request.searchFieldMask,
    );
    return ((response['places'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => PlaceData.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  Future<List<PlaceData>> _searchNearbyOverHttp(
    NearbySearchRequest request,
  ) async {
    final response = await _post(
      path: 'places:searchNearby',
      body: request.toRestJson(),
      fieldMask: request.searchFieldMask,
    );
    return ((response['places'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => PlaceData.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> _post({
    required String path,
    required Map<String, Object?> body,
    required String fieldMask,
  }) async {
    final uri = _resolveUri(path);
    final response = await _httpClient.post(
      uri,
      headers: _headers(fieldMask: fieldMask),
      body: jsonEncode(body),
    );
    return _decode(response);
  }

  Future<Map<String, Object?>> _get({
    required String path,
    String? fieldMask,
    Map<String, String> queryParameters = const <String, String>{},
  }) async {
    final uri = _resolveUri(path, queryParameters: queryParameters);
    final response = await _httpClient.get(
      uri,
      headers: _headers(fieldMask: fieldMask ?? ''),
    );
    return _decode(response);
  }

  Uri _resolveUri(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
    bool treatPathAsAbsolute = false,
  }) {
    final baseUrl = treatPathAsAbsolute ? path : _placesBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = treatPathAsAbsolute
        ? ''
        : (path.startsWith('/') ? path.substring(1) : path);
    return Uri.parse(
      treatPathAsAbsolute ? normalizedBase : '$normalizedBase/$normalizedPath',
    ).replace(
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
  }

  Map<String, String> _headers({required String fieldMask}) {
    return <String, String>{
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': apiKey,
      if (fieldMask.isNotEmpty) 'X-Goog-FieldMask': fieldMask,
    };
  }

  Map<String, Object?> _decode(http.Response response) {
    final dynamic decoded = response.body.isEmpty
        ? <String, Object?>{}
        : jsonDecode(response.body);
    final body = (decoded as Map<Object?, Object?>).cast<String, Object?>();
    if (response.statusCode >= 400) {
      final error = (body['error'] as Map<Object?, Object?>?)
          ?.cast<String, Object?>();
      throw PlacesException(
        (error?['message'] ?? 'Google Places request failed.') as String,
        statusCode: response.statusCode,
        details: body,
      );
    }
    return body;
  }

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

  String _webFieldName(PlaceField field) {
    return switch (field) {
      PlaceField.googleMapsUri => 'googleMapsURI',
      PlaceField.websiteUri => 'websiteURI',
      PlaceField.iconMaskBaseUri => 'svgIconMaskURI',
      PlaceField.delivery => 'hasDelivery',
      PlaceField.dineIn => 'hasDineIn',
      PlaceField.takeout => 'hasTakeout',
      PlaceField.reservable => 'isReservable',
      PlaceField.outdoorSeating => 'hasOutdoorSeating',
      PlaceField.restroom => 'hasRestroom',
      PlaceField.goodForChildren => 'isGoodForChildren',
      PlaceField.goodForGroups => 'isGoodForGroups',
      _ => field.apiName,
    };
  }

  Object? _normalizeWebFieldValue(PlaceField field, Object? value) {
    if (field == PlaceField.iconMaskBaseUri &&
        value is String &&
        value.endsWith('.svg')) {
      return value.substring(0, value.length - 4);
    }
    return value;
  }
}

String _normalizeTimeZoneUrl(String value) {
  final normalized = value.endsWith('/')
      ? value.substring(0, value.length - 1)
      : value;
  return normalized.endsWith('/json') ? normalized : '$normalized/json';
}
