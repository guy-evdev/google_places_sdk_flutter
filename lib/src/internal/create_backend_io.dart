import 'package:http/http.dart' as http;

import 'backend.dart';
import 'places_http_backend.dart';
import '../places_client_options.dart';

PlacesBackend createPlacesBackend({
  required String apiKey,
  PlacesProxyConfiguration? proxyConfiguration,
  String? proxyBaseUrl,
  String? timeZoneBaseUrl,
  required PlacesClientOptions options,
  Object? httpClient,
}) {
  return PlacesHttpBackend(
    apiKey: apiKey,
    proxyConfiguration: proxyConfiguration,
    proxyBaseUrl: proxyBaseUrl,
    timeZoneBaseUrl: timeZoneBaseUrl,
    options: options,
    httpClient: httpClient is http.Client ? httpClient : null,
  );
}
