import 'backend.dart';
import 'create_backend_io.dart'
    if (dart.library.html) 'create_backend_web.dart'
    as backend_factory;

PlacesBackend createPlacesBackend({
  required String apiKey,
  String? proxyBaseUrl,
  String? timeZoneBaseUrl,
  Object? httpClient,
}) {
  return backend_factory.createPlacesBackend(
    apiKey: apiKey,
    proxyBaseUrl: proxyBaseUrl,
    timeZoneBaseUrl: timeZoneBaseUrl,
    httpClient: httpClient,
  );
}
