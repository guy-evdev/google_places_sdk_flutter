import 'backend.dart';
import '../places_client_options.dart';
import 'create_backend_io.dart'
    if (dart.library.js_interop) 'create_backend_web.dart'
    as backend_factory;

/// Creates the platform backend, chosen by conditional import: the web backend when
/// `dart.library.js_interop` is available (JavaScript and Wasm web builds), the
/// HTTP backend otherwise.
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
