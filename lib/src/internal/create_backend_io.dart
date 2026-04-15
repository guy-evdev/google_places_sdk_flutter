import 'package:http/http.dart' as http;

import 'backend.dart';
import 'places_http_backend.dart';

PlacesBackend createPlacesBackend({
  required String apiKey,
  String? proxyBaseUrl,
  String? timeZoneBaseUrl,
  Object? httpClient,
}) {
  return PlacesHttpBackend(
    apiKey: apiKey,
    proxyBaseUrl: proxyBaseUrl,
    timeZoneBaseUrl: timeZoneBaseUrl,
    httpClient: httpClient is http.Client ? httpClient : null,
  );
}
