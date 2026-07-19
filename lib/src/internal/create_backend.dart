import 'backend.dart';
import '../places_client_options.dart';
import 'create_backend_io.dart'
    if (dart.library.html) 'create_backend_web.dart'
    as backend_factory;

PlacesBackend createPlacesBackend({
  required String apiKey,
  PlacesProxyConfiguration? proxyConfiguration,
  String? proxyBaseUrl,
  String? timeZoneBaseUrl,
  required PlacesClientOptions options,
  Object? httpClient,
}) {
  return backend_factory.createPlacesBackend(
    apiKey: apiKey,
    proxyConfiguration: proxyConfiguration,
    proxyBaseUrl: proxyBaseUrl,
    timeZoneBaseUrl: timeZoneBaseUrl,
    options: options,
    httpClient: httpClient,
  );
}
