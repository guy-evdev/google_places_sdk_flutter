import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/place_models.dart';

/// Decodes a Places HTTP response body, throwing a [PlacesException] for
/// malformed bodies and for Google or proxy errors.
Map<String, Object?> decodePlacesResponse(
  http.Response response, {
  required PlacesOperation operation,
  required bool fromProxy,
}) {
  Object? decoded;
  if (response.body.isNotEmpty) {
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw _invalidResponse(
        response,
        operation: operation,
        code: 'malformed_json',
        fromProxy: fromProxy,
      );
    }
  }
  if (decoded is! Map<Object?, Object?>) {
    throw _invalidResponse(
      response,
      operation: operation,
      code: response.body.isEmpty ? 'empty_response' : 'non_object_response',
      fromProxy: fromProxy,
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
          ? (!fromProxy ? PlacesErrorKind.http : PlacesErrorKind.proxy)
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

/// Builds the exception for a response whose body is not a JSON object.
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

/// Ensures a Time Zone base URL ends in `/json`, without disturbing any query
/// string the caller configured on it.
String normalizeTimeZoneUrl(String value) {
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
