import '../models/place_models.dart';
import '../places_client_options.dart';
import '../places_cancellation_token.dart';
import 'error_handling.dart';

Future<Map<String, String>> proxyAuthenticationHeaders(
  PlacesProxyConfiguration? configuration,
  PlacesProxyRequest request,
  Duration timeout, {
  PlacesCancellationToken? cancellationToken,
}) async {
  final provider = configuration?.authentication;
  if (provider == null) {
    return const <String, String>{};
  }
  final provided = await runPlacesOperation<Map<String, String>>(
    operation: request.operation,
    timeout: timeout,
    fallbackKind: PlacesErrorKind.proxy,
    action: () async => provider(request),
    cancellationToken: cancellationToken,
  );
  final result = <String, String>{};
  final names = <String>{};
  for (final entry in provided.entries) {
    final normalizedName = entry.key.trim().toLowerCase();
    if (normalizedName.isEmpty ||
        !_headerName.hasMatch(entry.key) ||
        !names.add(normalizedName) ||
        _reservedHeaders.contains(normalizedName) ||
        entry.value.contains('\r') ||
        entry.value.contains('\n')) {
      throw PlacesException.configuration(
        'Proxy authentication returned an unsafe or reserved header.',
        operation: request.operation,
        code: 'unsafe_proxy_authentication_header',
      );
    }
    result[entry.key] = entry.value;
  }
  return result;
}

final RegExp _headerName = RegExp(r"^[!#$%&'*+.^_`|~0-9A-Za-z-]+$");
const Set<String> _reservedHeaders = <String>{
  'content-length',
  'content-type',
  'host',
  'x-goog-api-key',
  'x-goog-fieldmask',
  'x-goog-user-project',
};
