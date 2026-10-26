import 'backend.dart';
import 'places_web_backend.dart';
import '../models/place_models.dart';
import '../places_client_options.dart';

/// Creates the web backend; throws a configuration error if an [httpClient] is
/// injected.
PlacesBackend createPlacesBackend({
  required String apiKey,
  PlacesProxyConfiguration? proxyConfiguration,
  String? proxyBaseUrl,
  String? timeZoneBaseUrl,
  required PlacesClientOptions options,
  Object? httpClient,
}) {
  if (httpClient != null) {
    throw const PlacesException.configuration(
      'An injected HTTP client is not supported by the web backend.',
      code: 'unsupported_web_http_client',
    );
  }
  return PlacesWebBackend(
    apiKey: apiKey,
    proxyConfiguration: proxyConfiguration,
    proxyBaseUrl: proxyBaseUrl,
    timeZoneBaseUrl: timeZoneBaseUrl,
    options: options,
  );
}
