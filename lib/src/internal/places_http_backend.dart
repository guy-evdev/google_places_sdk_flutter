import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_models.dart';
import '../places_client_options.dart';
import '../places_cancellation_token.dart';
import 'backend.dart';
import 'error_handling.dart';
import 'proxy_transport.dart';

class PlacesHttpBackend implements PlacesBackend {
  PlacesHttpBackend({
    required this.apiKey,
    this.proxyConfiguration,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
    this.options = const PlacesClientOptions(),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client(),
       _ownsHttpClient =
           httpClient == null ||
           options.httpClientOwnership ==
               PlacesHttpClientOwnership.placesClient {
    proxyConfiguration?.validate();
    options.applicationIdentity?.validate();
    if (proxyConfiguration != null && proxyBaseUrl != null) {
      throw const PlacesException.configuration(
        'Configure either proxyConfiguration or proxyBaseUrl, not both.',
        code: 'conflicting_proxy_configuration',
      );
    }
  }

  static const _defaultPlacesBaseUrl = 'https://places.googleapis.com/v1';
  static const _defaultTimeZoneBaseUrl =
      'https://maps.googleapis.com/maps/api/timezone/json';

  final String apiKey;
  final PlacesProxyConfiguration? proxyConfiguration;
  final String? proxyBaseUrl;
  final String? timeZoneBaseUrl;
  final PlacesClientOptions options;
  final http.Client _httpClient;
  final bool _ownsHttpClient;

  static const _autocompletePlaceFieldMask =
      'suggestions.placePrediction.place,'
      'suggestions.placePrediction.placeId,'
      'suggestions.placePrediction.text,'
      'suggestions.placePrediction.structuredFormat.mainText,'
      'suggestions.placePrediction.structuredFormat.secondaryText,'
      'suggestions.placePrediction.distanceMeters,'
      'suggestions.placePrediction.types';

  bool get _usesProxy => proxyConfiguration != null || proxyBaseUrl != null;

  String get _placesBaseUrl =>
      proxyConfiguration?.placesEndpoint.toString() ??
      proxyBaseUrl ??
      _defaultPlacesBaseUrl;

  String get _timeZoneUrl =>
      _normalizeTimeZoneUrl(timeZoneBaseUrl ?? _defaultTimeZoneBaseUrl);

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
    final suggestions = ((response['suggestions'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => item.cast<String, Object?>())
        .where(
          (item) =>
              item['placePrediction'] != null ||
              item['queryPrediction'] != null,
        )
        .map(AutocompleteSuggestion.fromRestJson)
        .toList(growable: false);
    return suggestions;
  }

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {}

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    request.validate();
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
        if (request.sessionToken != null)
          'sessionToken': request.sessionToken!.value,
      },
      cancellationToken: cancellationToken,
    );
    return PlaceData.fromJson(response);
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final response = await _get(
      path: request.mediaPath,
      operation: PlacesOperation.photoMedia,
      queryParameters: <String, String>{
        ...request.toQueryParameters(),
        if (!_usesProxy) 'key': apiKey,
      },
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
    final response = await _getTimeZone(
      operation: PlacesOperation.timeZone,
      queryParameters: <String, String>{
        'location':
            '${request.location.latitude},${request.location.longitude}',
        'timestamp': (timestamp.millisecondsSinceEpoch ~/ 1000).toString(),
        if (proxyTimeZoneEndpoint == null) 'key': apiKey,
        if (request.languageCode != null) 'language': request.languageCode!,
      },
      cancellationToken: cancellationToken,
    );
    return PlaceTimeZoneData.fromJson(response, timestamp: timestamp);
  }

  @override
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final page = await searchTextPage(
      request,
      cancellationToken: cancellationToken,
    );
    return page.results;
  }

  @override
  Future<TextSearchPage> searchTextPage(
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

  @override
  Future<List<PlaceData>> searchNearby(
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

  @override
  Future<void> close() async {
    if (_ownsHttpClient) {
      _httpClient.close();
    }
  }

  Future<Map<String, Object?>> _post({
    required String path,
    required Map<String, Object?> body,
    required String fieldMask,
    required PlacesOperation operation,
    PlacesCancellationToken? cancellationToken,
  }) async {
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

  Future<Map<String, Object?>> _getTimeZone({
    required Map<String, String> queryParameters,
    required PlacesOperation operation,
    PlacesCancellationToken? cancellationToken,
  }) async {
    final proxyEndpoint = proxyConfiguration?.timeZoneEndpoint;
    final uri = _resolveUri(
      proxyEndpoint?.toString() ?? _timeZoneUrl,
      queryParameters: queryParameters,
      treatPathAsAbsolute: true,
      operation: operation,
    );
    final headers = await _headers(
      uri: uri,
      method: 'GET',
      fieldMask: '',
      operation: operation,
      timeZoneProxyRequest: proxyEndpoint != null,
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
    final body = _decode(
      response,
      operation: operation,
      fromProxy: proxyEndpoint != null,
    );
    final status = (body['status'] ?? 'UNKNOWN_ERROR') as String;
    if (status != 'OK') {
      throw PlacesException(
        (body['errorMessage'] ?? 'Google Time Zone request failed.') as String,
        kind: PlacesErrorKind.googleApi,
        statusCode: response.statusCode,
        code: status,
        retryable: status == 'UNKNOWN_ERROR',
        operation: operation,
        details: <String, Object?>{'status': status},
      );
    }
    return body;
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
      final uri =
          Uri.parse(
            treatPathAsAbsolute
                ? normalizedBase
                : '$normalizedBase/$normalizedPath',
          ).replace(
            queryParameters: queryParameters.isEmpty ? null : queryParameters,
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
      if (!proxyRequest && options.applicationIdentity != null)
        ...options.applicationIdentity!.headers,
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
      final googleCode =
          error?['status']?.toString() ?? error?['code']?.toString();
      final message = error?['message'];
      final statusCode = response.statusCode;
      throw PlacesException(
        message is String && message.isNotEmpty
            ? message
            : 'The Places HTTP request failed.',
        kind: error == null
            ? (!proxyResponse ? PlacesErrorKind.http : PlacesErrorKind.proxy)
            : PlacesErrorKind.googleApi,
        statusCode: statusCode,
        code: googleCode ?? 'http_error',
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
}

String _normalizeTimeZoneUrl(String value) {
  final normalized = value.endsWith('/')
      ? value.substring(0, value.length - 1)
      : value;
  return normalized.endsWith('/json') ? normalized : '$normalized/json';
}
