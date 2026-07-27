import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import '../models/place_models.dart';
import '../places_client_options.dart';
import '../places_cancellation_token.dart';
import 'autocomplete_session_cache.dart';
import 'backend.dart';
import 'error_handling.dart';
import 'place_field_mapping.dart';
import 'proxy_transport.dart';

class PlacesWebBackend implements PlacesBackend {
  PlacesWebBackend({
    required this.apiKey,
    this.proxyConfiguration,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
    this.options = const PlacesClientOptions(),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? BrowserClient() {
    proxyConfiguration?.validate();
    options.web.validate();
    if (proxyConfiguration != null && proxyBaseUrl != null) {
      throw const PlacesException.configuration(
        'Configure either proxyConfiguration or proxyBaseUrl, not both.',
        code: 'conflicting_proxy_configuration',
      );
    }
    if (options.applicationIdentity != null) {
      throw const PlacesException.configuration(
        'Application identity headers are not supported by the web backend.',
        code: 'unsupported_web_application_identity',
      );
    }
  }

  static const _mapsScriptId = 'google_places_sdk_flutter_maps_js';
  static const _defaultPlacesBaseUrl = 'https://places.googleapis.com/v1';
  static const _defaultTimeZoneBaseUrl =
      'https://maps.googleapis.com/maps/api/timezone/json';
  static const _autocompletePlaceFieldMask =
      'suggestions.placePrediction.place,'
      'suggestions.placePrediction.placeId,'
      'suggestions.placePrediction.text,'
      'suggestions.placePrediction.structuredFormat.mainText,'
      'suggestions.placePrediction.structuredFormat.secondaryText,'
      'suggestions.placePrediction.distanceMeters,'
      'suggestions.placePrediction.types';

  final String apiKey;
  final PlacesProxyConfiguration? proxyConfiguration;
  final String? proxyBaseUrl;
  final String? timeZoneBaseUrl;
  final PlacesClientOptions options;
  final http.Client _httpClient;
  final AutocompleteSessionCache<JSObject, JSObject> _autocompleteSessions =
      AutocompleteSessionCache<JSObject, JSObject>();

  static Completer<JSObject>? _placesLibraryCompleter;
  static String? _loadedApiKey;
  static PlacesWebVersionChannel? _loadedVersionChannel;
  static String? _loadingApiKey;
  static PlacesWebVersionChannel? _loadingVersionChannel;

  bool get _usesProxy => proxyConfiguration != null || proxyBaseUrl != null;

  bool get _usesHttpAsPrimary => _usesProxy && apiKey.trim().isEmpty;

  String get _placesBaseUrl =>
      proxyConfiguration?.placesEndpoint.toString() ??
      proxyBaseUrl ??
      _defaultPlacesBaseUrl;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final suggestions = await autocompleteSuggestions(
      request,
      cancellationToken: cancellationToken,
    );
    return suggestions.whereType<PlaceSuggestion>().toList(growable: false);
  }

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    request.validate();
    if (_usesHttpAsPrimary) {
      return _autocompleteSuggestionsOverHttp(
        request,
        cancellationToken: cancellationToken,
      );
    }
    return _runJavaScript(
      PlacesOperation.autocomplete,
      () => _autocompleteSuggestions(request),
      cancellationToken: cancellationToken,
    );
  }

  Future<List<AutocompleteSuggestion>> _autocompleteSuggestions(
    AutocompleteRequest request,
  ) async {
    final library = await _loadPlacesLibrary();
    final autocompleteSuggestion =
        library.getProperty('AutocompleteSuggestion'.toJS) as JSFunction;
    final fetchSuggestions =
        autocompleteSuggestion.getProperty('fetchAutocompleteSuggestions'.toJS)
            as JSFunction;
    final sessionToken = request.sessionToken;
    final jsRequest = _jsifyAutocompleteRequest(request, library: library);
    final requestGeneration = sessionToken == null
        ? null
        : _autocompleteSessions.beginRequest(sessionToken.value);
    final result =
        await (fetchSuggestions.callAsFunction(
                  autocompleteSuggestion,
                  jsRequest,
                )
                as JSPromise<JSAny?>)
            .toDart;
    final suggestions =
        (result as JSObject).getProperty('suggestions'.toJS) as JSObject;
    final length =
        (suggestions.getProperty('length'.toJS) as JSNumber).toDartInt;
    final items = <AutocompleteSuggestion>[];
    final cachePredictions =
        sessionToken != null &&
        requestGeneration != null &&
        _autocompleteSessions.beginPredictionSet(
          sessionToken.value,
          requestGeneration,
        );
    for (var index = 0; index < length; index++) {
      final suggestion = suggestions.getProperty(index.toJS) as JSObject;
      final prediction = suggestion.getProperty('placePrediction'.toJS);
      if (prediction != null) {
        items.add(
          _predictionToSuggestion(
            prediction as JSObject,
            sessionToken: cachePredictions ? sessionToken : null,
          ),
        );
        continue;
      }
      final queryPrediction = suggestion.getProperty('queryPrediction'.toJS);
      if (queryPrediction != null) {
        items.add(_queryPredictionToSuggestion(queryPrediction as JSObject));
      }
    }
    return items;
  }

  Future<List<AutocompleteSuggestion>> _autocompleteSuggestionsOverHttp(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final response = await _post(
      path: 'places:autocomplete',
      body: request.toRestJson(),
      fieldMask: request.includeQueryPredictions
          ? '$_autocompletePlaceFieldMask,suggestions.queryPrediction.text'
          : _autocompletePlaceFieldMask,
      operation: PlacesOperation.autocomplete,
      cancellationToken: cancellationToken,
    );
    return ((response['suggestions'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => item.cast<String, Object?>())
        .where(
          (item) =>
              item['placePrediction'] != null ||
              item['queryPrediction'] != null,
        )
        .map(AutocompleteSuggestion.fromRestJson)
        .toList(growable: false);
  }

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    request.validate();
    return _runJavaScript(
      PlacesOperation.placeDetails,
      () => _fetchPlace(request, cancellationToken: cancellationToken),
      cancellationToken: cancellationToken,
    );
  }

  Future<PlaceData> _fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    if (_usesHttpAsPrimary) {
      return _fetchPlaceOverHttp(request, cancellationToken: cancellationToken);
    }
    var usedCachedPrediction = false;
    try {
      final library = await _loadPlacesLibrary();
      final cachedPrediction = request.sessionToken == null
          ? null
          : _autocompleteSessions.takePrediction(
              request.sessionToken!.value,
              request.placeId,
            );
      final JSObject place;
      if (cachedPrediction != null) {
        usedCachedPrediction = true;
        final toPlace =
            cachedPrediction.getProperty('toPlace'.toJS) as JSFunction;
        place = toPlace.callAsFunction(cachedPrediction) as JSObject;
      } else {
        final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
        place = placeCtor.callAsConstructor<JSObject>(
          <String, Object?>{
                'id': request.placeId,
                if (request.languageCode != null)
                  'requestedLanguage': request.languageCode,
                if (request.regionCode != null)
                  'requestedRegion': request.regionCode,
              }.jsify()!
              as JSObject,
        );
      }

      final fetchFields = place.getProperty('fetchFields'.toJS) as JSFunction;
      await (fetchFields.callAsFunction(
                place,
                <String, Object?>{
                  'fields': request.fields.map(webPlaceFieldName).toList(),
                }.jsify()!,
              )
              as JSPromise<JSAny?>)
          .toDart;

      return PlaceData.fromJson(_extractPlaceMap(place, request.fields));
    } catch (error) {
      if (!_shouldFallbackToHttp(error)) {
        rethrow;
      }
      // A Dart token used for Maps JavaScript represents a generated JS token,
      // not a compatible REST token. HTTP fallback is a separate operation.
      return _fetchPlaceOverHttp(
        request,
        includeSessionToken: false,
        cancellationToken: cancellationToken,
      );
    } finally {
      if (usedCachedPrediction && request.sessionToken != null) {
        await endAutocompleteSession(request.sessionToken!);
      }
    }
  }

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {
    _autocompleteSessions.end(token.value);
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    // Authentication travels in the X-Goog-Api-Key header, like every other
    // operation. A key in the query string would be recorded by proxy logs,
    // CDN logs, and browser history.
    final response = await _get(
      path: request.mediaPath,
      operation: PlacesOperation.photoMedia,
      queryParameters: request.toQueryParameters(),
      cancellationToken: cancellationToken,
    );
    return PlacePhotoMedia.fromJson(response);
  }

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    request.validate();
    _ensureHttpAllowed(PlacesOperation.timeZone);
    final proxyTimeZoneEndpoint = proxyConfiguration?.timeZoneEndpoint;
    if (proxyConfiguration != null && proxyTimeZoneEndpoint == null) {
      throw const PlacesException.configuration(
        'The proxy does not define a Time Zone endpoint.',
        operation: PlacesOperation.timeZone,
        code: 'missing_proxy_time_zone_endpoint',
      );
    }
    if (proxyTimeZoneEndpoint == null && apiKey.trim().isEmpty) {
      throw PlacesException.configuration(
        'apiKey cannot be empty for Time Zone requests.',
        operation: PlacesOperation.timeZone,
        code: 'missing_api_key',
      );
    }
    final timestamp = request.timestamp?.toUtc() ?? DateTime.now().toUtc();
    final Uri uri;
    try {
      uri =
          Uri.parse(
            proxyTimeZoneEndpoint?.toString() ??
                _normalizeTimeZoneUrl(
                  timeZoneBaseUrl ?? _defaultTimeZoneBaseUrl,
                ),
          ).replace(
            queryParameters: <String, String>{
              'location':
                  '${request.location.latitude},${request.location.longitude}',
              'timestamp': (timestamp.millisecondsSinceEpoch ~/ 1000)
                  .toString(),
              if (proxyTimeZoneEndpoint == null) 'key': apiKey,
              if (request.languageCode != null)
                'language': request.languageCode!,
            },
          );
    } on FormatException {
      throw const PlacesException.configuration(
        'The configured Time Zone endpoint is not a valid URI.',
        operation: PlacesOperation.timeZone,
        code: 'invalid_endpoint',
      );
    }
    final headers = await _headers(
      uri: uri,
      method: 'GET',
      fieldMask: '',
      operation: PlacesOperation.timeZone,
      timeZoneProxyRequest: proxyTimeZoneEndpoint != null,
      cancellationToken: cancellationToken,
    );
    final response = await sendPlacesHttpRequest(
      client: _httpClient,
      method: 'GET',
      uri: uri,
      headers: headers,
      operation: PlacesOperation.timeZone,
      timeout: options.requestTimeout,
      cancellationToken: cancellationToken,
    );
    final body = _decode(
      response,
      operation: PlacesOperation.timeZone,
      fromProxy: proxyTimeZoneEndpoint != null,
    );
    final status = (body['status'] ?? 'UNKNOWN_ERROR') as String;
    if (status != 'OK') {
      throw PlacesException(
        (body['errorMessage'] ?? 'Google Time Zone request failed.') as String,
        kind: PlacesErrorKind.googleApi,
        statusCode: response.statusCode,
        code: status,
        retryable: status == 'UNKNOWN_ERROR',
        operation: PlacesOperation.timeZone,
        details: <String, Object?>{'status': status},
      );
    }
    return PlaceTimeZoneData.fromJson(body, timestamp: timestamp);
  }

  @override
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    request.validate();
    return _runJavaScript(
      PlacesOperation.textSearch,
      () => _searchText(request, cancellationToken: cancellationToken),
      cancellationToken: cancellationToken,
    );
  }

  Future<List<PlaceData>> _searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    if (_usesHttpAsPrimary || request.pageToken != null) {
      return (await _searchTextPageOverHttp(
        request,
        cancellationToken: cancellationToken,
      )).results;
    }
    try {
      final library = await _loadPlacesLibrary();
      final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
      final requestMap = <String, Object?>{
        'textQuery': request.textQuery,
        'fields': request.fields.map(webPlaceFieldName).toList(),
        if (request.languageCode != null) 'language': request.languageCode,
        if (request.regionCode != null) 'region': request.regionCode,
        if (request.includedType != null) 'includedType': request.includedType,
        if (request.strictTypeFiltering) 'strictTypeFiltering': true,
        if (request.locationBias != null)
          'locationBias': request.locationBias!.area.toWebJson(),
        if (request.locationRestriction != null)
          'locationRestriction': request.locationRestriction!.area.toWebJson(),
        if (request.pageSize != null) 'maxResultCount': request.pageSize,
        // ignore: deprecated_member_use_from_same_package
        if (request.pageSize == null && request.maxResultCount != null)
          // ignore: deprecated_member_use_from_same_package
          'maxResultCount': request.maxResultCount,
        if (request.priceLevels.isNotEmpty)
          'priceLevels': request.priceLevels
              .map((level) => _webPriceLevel(library, level))
              .toList(),
        if (request.includePureServiceAreaBusinesses)
          'pureServiceAreaBusinessesIncluded': true,
        if (request.includeFutureOpeningBusinesses)
          'futureOpeningBusinessesIncluded': true,
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
      return _searchTextOverHttp(request, cancellationToken: cancellationToken);
    }
  }

  @override
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _searchTextPageOverHttp(request, cancellationToken: cancellationToken);

  @override
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    request.validate();
    return _runJavaScript(
      PlacesOperation.nearbySearch,
      () => _searchNearby(request, cancellationToken: cancellationToken),
      cancellationToken: cancellationToken,
    );
  }

  Future<List<PlaceData>> _searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    if (_usesHttpAsPrimary) {
      return _searchNearbyOverHttp(
        request,
        cancellationToken: cancellationToken,
      );
    }
    try {
      final library = await _loadPlacesLibrary();
      final placeCtor = library.getProperty('Place'.toJS) as JSFunction;
      final requestMap = <String, Object?>{
        'fields': request.fields.map(webPlaceFieldName).toList(),
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
        if (request.includeFutureOpeningBusinesses)
          'futureOpeningBusinessesIncluded': true,
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
      return _searchNearbyOverHttp(
        request,
        cancellationToken: cancellationToken,
      );
    }
  }

  @override
  Future<void> close() async {
    _autocompleteSessions.clear();
    _httpClient.close();
  }

  Future<T> _runJavaScript<T>(
    PlacesOperation operation,
    Future<T> Function() action, {
    PlacesCancellationToken? cancellationToken,
  }) {
    return runPlacesOperation<T>(
      operation: operation,
      timeout: options.requestTimeout,
      fallbackKind: PlacesErrorKind.javascript,
      action: action,
      cancellationToken: cancellationToken,
    );
  }

  Future<JSObject> _loadPlacesLibrary() async {
    if (apiKey.trim().isEmpty) {
      throw const PlacesException.configuration(
        'apiKey cannot be empty for Maps JavaScript requests.',
        code: 'missing_api_key',
      );
    }
    final activeApiKey = _loadedApiKey ?? _loadingApiKey;
    if (activeApiKey != null && activeApiKey != apiKey) {
      throw const PlacesException.configuration(
        'Google Maps JavaScript API is already loading or loaded with a different API key.',
        code: 'conflicting_javascript_api_key',
      );
    }
    final activeVersion = _loadedVersionChannel ?? _loadingVersionChannel;
    if (activeVersion != null && activeVersion != options.web.versionChannel) {
      throw const PlacesException.configuration(
        'Google Maps JavaScript API is already loading or loaded with a different version channel.',
        code: 'conflicting_javascript_version_channel',
      );
    }
    final existingCompleter = _placesLibraryCompleter;
    if (existingCompleter != null) {
      return existingCompleter.future;
    }
    final completer = Completer<JSObject>();
    _placesLibraryCompleter = completer;
    _loadingApiKey = apiKey;
    _loadingVersionChannel = options.web.versionChannel;
    try {
      final library = await _initializePlacesLibrary().timeout(
        options.web.initializationTimeout,
        onTimeout: () => throw const PlacesException(
          'Google Maps JavaScript did not initialize before the deadline.',
          kind: PlacesErrorKind.timeout,
          code: 'javascript_initialization_timeout',
          retryable: true,
          operation: PlacesOperation.clientInitialization,
        ),
      );
      _loadedApiKey = apiKey;
      _loadedVersionChannel = options.web.versionChannel;
      completer.complete(library);
    } catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
      if (identical(_placesLibraryCompleter, completer)) {
        _placesLibraryCompleter = null;
      }
    } finally {
      _loadingApiKey = null;
      _loadingVersionChannel = null;
    }
    return completer.future;
  }

  Future<JSObject> _initializePlacesLibrary() async {
    if (!_hasGoogleMapsImportLibrary()) {
      await _injectMapsScript();
    }
    await _waitForImportLibrary();
    final google = web.window.getProperty('google'.toJS) as JSObject;
    final maps = google.getProperty('maps'.toJS) as JSObject;
    final importLibrary = maps.getProperty('importLibrary'.toJS) as JSFunction;
    final library =
        await (importLibrary.callAsFunction(maps, 'places'.toJS)
                as JSPromise<JSAny?>)
            .toDart;
    return library as JSObject;
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
      await _waitForImportLibrary();
      return;
    }
    final scriptUri =
        Uri.https('maps.googleapis.com', '/maps/api/js', <String, String>{
          'key': apiKey,
          'loading': 'async',
          'libraries': 'places',
          'v': options.web.versionChannel.name,
        });
    final script = web.HTMLScriptElement()
      ..id = _mapsScriptId
      ..async = true
      ..src = scriptUri.toString();
    final cspNonce = options.web.cspNonce;
    if (cspNonce != null) {
      script.nonce = cspNonce;
    }
    final load = script.onLoad.first;
    final error = script.onError.first.then<void>(
      (_) => throw const PlacesException(
        'Failed to load the Google Maps JavaScript Places library.',
        kind: PlacesErrorKind.javascript,
        code: 'javascript_load_failure',
        retryable: true,
        operation: PlacesOperation.clientInitialization,
      ),
    );
    web.document.head!.append(script);
    await Future.any(<Future<void>>[load, error]).timeout(
      options.web.initializationTimeout,
      onTimeout: () => throw const PlacesException(
        'Google Maps JavaScript did not load before the initialization deadline.',
        kind: PlacesErrorKind.timeout,
        code: 'javascript_initialization_timeout',
        retryable: true,
        operation: PlacesOperation.clientInitialization,
      ),
    );
  }

  Future<void> _waitForImportLibrary() async {
    final stopwatch = Stopwatch()..start();
    while (stopwatch.elapsed < options.web.initializationTimeout) {
      if (_hasGoogleMapsImportLibrary()) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw const PlacesException(
      'Google Maps JavaScript Places library did not finish initializing.',
      kind: PlacesErrorKind.timeout,
      code: 'javascript_initialization_timeout',
      retryable: true,
      operation: PlacesOperation.clientInitialization,
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
            'pureServiceAreaBusinessesIncluded': true,
          if (request.includeFutureOpeningBusinesses)
            'futureOpeningBusinessesIncluded': true,
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
    return _autocompleteSessions.tokenFor(token.value, () {
      final tokenCtor =
          library.getProperty('AutocompleteSessionToken'.toJS) as JSFunction;
      return tokenCtor.callAsConstructor<JSObject>();
    });
  }

  PlaceSuggestion _predictionToSuggestion(
    JSObject prediction, {
    required AutocompleteSessionToken? sessionToken,
  }) {
    final text = prediction.getProperty('text'.toJS);
    final structuredFormat = prediction.getProperty('structuredFormat'.toJS);
    final types = _listOfStrings(prediction.getProperty('types'.toJS));
    final placeId =
        ((prediction.getProperty('placeId'.toJS) as JSString?)?.toDart) ?? '';
    if (sessionToken != null) {
      _autocompleteSessions.putPrediction(
        sessionToken.value,
        placeId,
        prediction,
      );
    }

    return PlaceSuggestion(
      placeId: placeId,
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
      final value = _fieldValue(place, webPlaceFieldName(field));
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

  bool _shouldFallbackToHttp(Object error) => shouldFallbackToHttp(error);

  Future<PlaceData> _fetchPlaceOverHttp(
    PlaceDetailsRequest request, {
    bool includeSessionToken = true,
    PlacesCancellationToken? cancellationToken,
  }) async {
    final path = request.placeId.startsWith('places/')
        ? request.placeId
        : 'places/${Uri.encodeComponent(request.placeId)}';
    final response = await _get(
      path: path,
      fieldMask: request.detailsFieldMask,
      operation: PlacesOperation.placeDetails,
      queryParameters: <String, String>{
        if (request.languageCode != null) 'languageCode': request.languageCode!,
        if (request.regionCode != null) 'regionCode': request.regionCode!,
        if (includeSessionToken && request.sessionToken != null)
          'sessionToken': request.sessionToken!.value,
      },
      cancellationToken: cancellationToken,
    );
    return PlaceData.fromJson(response);
  }

  Future<List<PlaceData>> _searchTextOverHttp(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    return (await _searchTextPageOverHttp(
      request,
      cancellationToken: cancellationToken,
    )).results;
  }

  Future<TextSearchPage> _searchTextPageOverHttp(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final response = await _post(
      path: 'places:searchText',
      body: request.toRestJson(),
      fieldMask: '${request.searchFieldMask},nextPageToken,searchUri',
      operation: PlacesOperation.textSearch,
      cancellationToken: cancellationToken,
    );
    return TextSearchPage.fromJson(response);
  }

  Future<List<PlaceData>> _searchNearbyOverHttp(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final response = await _post(
      path: 'places:searchNearby',
      body: request.toRestJson(),
      fieldMask: request.searchFieldMask,
      operation: PlacesOperation.nearbySearch,
      cancellationToken: cancellationToken,
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
    required PlacesOperation operation,
    PlacesCancellationToken? cancellationToken,
  }) async {
    _ensureHttpAllowed(operation);
    final uri = _resolveUri(path, operation: operation);
    final headers = await _headers(
      uri: uri,
      method: 'POST',
      fieldMask: fieldMask,
      operation: operation,
      cancellationToken: cancellationToken,
    );
    final response = await sendPlacesHttpRequest(
      client: _httpClient,
      method: 'POST',
      uri: uri,
      headers: headers,
      body: jsonEncode(body),
      operation: operation,
      timeout: options.requestTimeout,
      cancellationToken: cancellationToken,
    );
    return _decode(response, operation: operation);
  }

  Future<Map<String, Object?>> _get({
    required String path,
    String? fieldMask,
    Map<String, String> queryParameters = const <String, String>{},
    required PlacesOperation operation,
    PlacesCancellationToken? cancellationToken,
  }) async {
    _ensureHttpAllowed(operation);
    final uri = _resolveUri(
      path,
      queryParameters: queryParameters,
      operation: operation,
    );
    final headers = await _headers(
      uri: uri,
      method: 'GET',
      fieldMask: fieldMask ?? '',
      operation: operation,
      cancellationToken: cancellationToken,
    );
    final response = await sendPlacesHttpRequest(
      client: _httpClient,
      method: 'GET',
      uri: uri,
      headers: headers,
      operation: operation,
      timeout: options.requestTimeout,
      cancellationToken: cancellationToken,
    );
    return _decode(response, operation: operation);
  }

  Uri _resolveUri(
    String path, {
    Map<String, String> queryParameters = const <String, String>{},
    bool treatPathAsAbsolute = false,
    required PlacesOperation operation,
  }) {
    final baseUrl = treatPathAsAbsolute ? path : _placesBaseUrl;
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final normalizedPath = treatPathAsAbsolute
        ? ''
        : (path.startsWith('/') ? path.substring(1) : path);
    try {
      final parsed = Uri.parse(
        treatPathAsAbsolute
            ? normalizedBase
            : '$normalizedBase/$normalizedPath',
      );
      // Preserve any query already present on a caller-configured endpoint,
      // such as a routing token on a custom timeZoneBaseUrl. Our own
      // parameters win on conflict.
      final mergedQuery = <String, String>{
        ...parsed.queryParameters,
        ...queryParameters,
      };
      final uri = parsed.replace(
        queryParameters: mergedQuery.isEmpty ? null : mergedQuery,
      );
      if (!uri.isAbsolute ||
          uri.host.isEmpty ||
          (uri.scheme != 'https' && uri.scheme != 'http')) {
        throw const FormatException();
      }
      return uri;
    } on FormatException {
      throw PlacesException.configuration(
        'The configured Places endpoint is not a valid URI.',
        operation: operation,
        code: 'invalid_endpoint',
      );
    }
  }

  Future<Map<String, String>> _headers({
    required Uri uri,
    required String method,
    required String fieldMask,
    required PlacesOperation operation,
    bool timeZoneProxyRequest = false,
    PlacesCancellationToken? cancellationToken,
  }) async {
    final proxyRequest =
        _usesProxy &&
        (operation != PlacesOperation.timeZone || timeZoneProxyRequest);
    if (!proxyRequest && apiKey.trim().isEmpty) {
      throw PlacesException.configuration(
        'apiKey cannot be empty for direct Google Places requests.',
        operation: operation,
        code: 'missing_api_key',
      );
    }
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (!proxyRequest) 'X-Goog-Api-Key': apiKey,
      if (fieldMask.isNotEmpty) 'X-Goog-FieldMask': fieldMask,
    };
    if (proxyRequest) {
      headers.addAll(
        await proxyAuthenticationHeaders(
          proxyConfiguration,
          PlacesProxyRequest(operation: operation, method: method, uri: uri),
          options.requestTimeout,
          cancellationToken: cancellationToken,
        ),
      );
    }
    return headers;
  }

  void _ensureHttpAllowed(PlacesOperation operation) {
    switch (options.web.fallbackPolicy) {
      // ignore: deprecated_member_use_from_same_package
      case PlacesWebFallbackPolicy.direct:
        return;
      case PlacesWebFallbackPolicy.proxyOnly:
        if (_usesProxy) {
          return;
        }
        throw PlacesException.configuration(
          'This web operation requires a configured proxy.',
          operation: operation,
          code: 'web_proxy_required',
        );
      case PlacesWebFallbackPolicy.disabled:
        throw PlacesException.configuration(
          'HTTP operations are disabled by the web fallback policy.',
          operation: operation,
          code: 'web_http_disabled',
        );
    }
  }

  Map<String, Object?> _decode(
    http.Response response, {
    required PlacesOperation operation,
    bool? fromProxy,
  }) {
    final proxyResponse = fromProxy ?? _usesProxy;
    Object? decoded;
    if (response.body.isNotEmpty) {
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        throw _invalidResponse(
          response,
          operation: operation,
          code: 'malformed_json',
          fromProxy: proxyResponse,
        );
      }
    }
    if (decoded is! Map<Object?, Object?>) {
      throw _invalidResponse(
        response,
        operation: operation,
        code: response.body.isEmpty ? 'empty_response' : 'non_object_response',
        fromProxy: proxyResponse,
      );
    }
    final body = decoded.cast<String, Object?>();
    final error = body['error'] is Map<Object?, Object?>
        ? (body['error'] as Map<Object?, Object?>).cast<String, Object?>()
        : null;
    if (response.statusCode >= 400 || error != null) {
      final statusCode = response.statusCode;
      final message = error?['message'];
      throw PlacesException(
        message is String && message.isNotEmpty
            ? message
            : 'The Places HTTP request failed.',
        kind: error == null
            ? (!proxyResponse ? PlacesErrorKind.http : PlacesErrorKind.proxy)
            : PlacesErrorKind.googleApi,
        statusCode: statusCode,
        code:
            error?['status']?.toString() ??
            error?['code']?.toString() ??
            'http_error',
        retryable: statusCode == 408 || statusCode == 429 || statusCode >= 500,
        operation: operation,
        details: error == null
            ? null
            : <String, Object?>{
                if (error['status'] != null) 'status': error['status'],
                if (error['code'] != null) 'code': error['code'],
              },
      );
    }
    return body;
  }

  PlacesException _invalidResponse(
    http.Response response, {
    required PlacesOperation operation,
    required String code,
    required bool fromProxy,
  }) {
    final metadata = <String, Object?>{'bodyLength': response.bodyBytes.length};
    final contentType = response.headers['content-type'];
    if (contentType != null) {
      metadata['contentType'] = contentType;
    }
    return PlacesException(
      !fromProxy
          ? 'Google Places returned an invalid response.'
          : 'The configured Places proxy returned an invalid response.',
      kind: !fromProxy ? PlacesErrorKind.googleApi : PlacesErrorKind.proxy,
      statusCode: response.statusCode,
      code: code,
      retryable: response.statusCode >= 500,
      operation: operation,
      metadata: metadata,
    );
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

  JSAny _webPriceLevel(JSObject library, PlacePriceLevel level) {
    final values = library.getProperty('PriceLevel'.toJS) as JSObject;
    final name = level.restName.replaceFirst('PRICE_LEVEL_', '');
    return values.getProperty(name.toJS)!;
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

/// Whether a Maps JavaScript failure means "this field set is unsupported",
/// which is the only case the HTTP fallback is meant to cover.
///
/// Google ships Maps JavaScript on a weekly channel and can reword these
/// messages at any time. When that happens web users silently lose the
/// fallback and get an opaque `javascript_failure` instead, so the match is
/// deliberately broad and is pinned by a regression test against the wording
/// Google uses today. If that test starts failing because Google reworded a
/// message, widen this — never narrow it.
@visibleForTesting
bool shouldFallbackToHttp(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('unknown field')) {
    return true;
  }
  if (!message.contains('field')) {
    return false;
  }
  return message.contains('invalidvalueerror') ||
      message.contains('not a valid') ||
      message.contains('unsupported') ||
      message.contains('unexpected property');
}

/// Ensures a Time Zone base URL ends in `/json`, without disturbing any query
/// string the caller configured on it.
String _normalizeTimeZoneUrl(String value) {
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    return value;
  }
  var path = parsed.path;
  if (path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  if (path.endsWith('/json')) {
    return value;
  }
  return parsed.replace(path: '$path/json').toString();
}
