import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/place_models.dart';

/// Determines who closes an injected `package:http` client.
enum PlacesHttpClientOwnership {
  /// The caller retains ownership and closes the injected client.
  caller,

  /// `PlacesClient.close()` closes the injected client.
  placesClient,
}

/// Google Maps application restriction headers for direct mobile REST calls.
@immutable
class PlacesApplicationIdentity {
  const PlacesApplicationIdentity._({
    required this.androidPackageName,
    required this.androidCertificateFingerprint,
    required this.iosBundleIdentifier,
  });

  /// Creates Android package and SHA-1 certificate identity headers.
  const PlacesApplicationIdentity.android(
    String packageName,
    String sha1CertificateFingerprint,
  ) : this._(
        androidPackageName: packageName,
        androidCertificateFingerprint: sha1CertificateFingerprint,
        iosBundleIdentifier: null,
      );

  /// Creates an iOS bundle-identifier identity header.
  const PlacesApplicationIdentity.ios(String bundleIdentifier)
    : this._(
        androidPackageName: null,
        androidCertificateFingerprint: null,
        iosBundleIdentifier: bundleIdentifier,
      );

  /// Android application package name, when this is an Android identity.
  final String? androidPackageName;

  /// Android SHA-1 signing-certificate fingerprint.
  final String? androidCertificateFingerprint;

  /// iOS bundle identifier, when this is an iOS identity.
  final String? iosBundleIdentifier;

  bool get _isAndroid => androidPackageName != null;

  void validate() {
    if (_isAndroid) {
      final packageName = androidPackageName!;
      if (!_androidPackageName.hasMatch(packageName)) {
        throw const PlacesException.configuration(
          'The Android package name is not valid.',
          code: 'invalid_android_package_name',
        );
      }
      if (!_sha1Fingerprint.hasMatch(androidCertificateFingerprint!)) {
        throw const PlacesException.configuration(
          'The Android SHA-1 certificate fingerprint is not valid.',
          code: 'invalid_android_certificate_fingerprint',
        );
      }
      return;
    }
    if (!_iosBundleIdentifier.hasMatch(iosBundleIdentifier!)) {
      throw const PlacesException.configuration(
        'The iOS bundle identifier is not valid.',
        code: 'invalid_ios_bundle_identifier',
      );
    }
  }

  Map<String, String> get headers {
    validate();
    if (_isAndroid) {
      return <String, String>{
        'X-Android-Package': androidPackageName!,
        'X-Android-Cert': androidCertificateFingerprint!.toUpperCase(),
      };
    }
    return <String, String>{'X-Ios-Bundle-Identifier': iosBundleIdentifier!};
  }

  @override
  String toString() => _isAndroid
      ? 'PlacesApplicationIdentity.android(${androidPackageName!}, <redacted>)'
      : 'PlacesApplicationIdentity.ios(${iosBundleIdentifier!})';

  static final RegExp _androidPackageName = RegExp(
    r'^[A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z][A-Za-z0-9_]*)+$',
  );
  static final RegExp _iosBundleIdentifier = RegExp(
    r'^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
  );
  static final RegExp _sha1Fingerprint = RegExp(
    r'^[0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2}){19}$',
  );
}

/// Maps JavaScript release channel used when the package injects the script.
enum PlacesWebVersionChannel {
  /// The most current channel, updated weekly by Google.
  weekly,

  /// The more predictable channel, updated once per quarter.
  quarterly,
}

/// Controls HTTP behavior for operations not completed by Maps JavaScript.
enum PlacesWebFallbackPolicy {
  /// Allows direct client-side Google REST calls when no proxy is configured.
  ///
  /// This compatibility policy is deprecated because web-service credentials
  /// cannot be kept secret in client applications. It remains the default only
  /// for the `0.6.x` release line.
  @Deprecated(
    'Direct client-side REST fallback is insecure and is deprecated in 0.6.0. '
    'Use PlacesWebFallbackPolicy.proxyOnly with an authenticated proxy.',
  )
  direct,

  /// Allows HTTP operations only through a configured authenticated proxy.
  proxyOnly,

  /// Disables every HTTP operation, including proxy requests.
  disabled,
}

@immutable
/// Browser-specific loading and HTTP fallback behavior.
class PlacesWebOptions {
  const PlacesWebOptions({
    this.versionChannel = PlacesWebVersionChannel.weekly,
    this.cspNonce,
    this.initializationTimeout = const Duration(seconds: 10),
    // ignore: deprecated_member_use_from_same_package
    this.fallbackPolicy = PlacesWebFallbackPolicy.direct,
  });

  /// Maps JavaScript release channel used for injected scripts.
  final PlacesWebVersionChannel versionChannel;

  /// Optional Content Security Policy nonce copied to the injected script.
  ///
  /// This value is never included in errors or diagnostics.
  final String? cspNonce;

  /// Maximum duration for loading and initializing Maps JavaScript.
  final Duration initializationTimeout;

  /// Policy for REST operations and JavaScript-to-HTTP fallback.
  final PlacesWebFallbackPolicy fallbackPolicy;

  void validate() {
    if (initializationTimeout <= Duration.zero) {
      throw const PlacesException.configuration(
        'web.initializationTimeout must be greater than zero.',
        operation: PlacesOperation.clientInitialization,
        code: 'invalid_web_initialization_timeout',
      );
    }
    if (cspNonce != null && cspNonce!.isEmpty) {
      throw const PlacesException.configuration(
        'web.cspNonce cannot be empty.',
        operation: PlacesOperation.clientInitialization,
        code: 'invalid_csp_nonce',
      );
    }
  }
}

/// Describes a request before proxy authentication headers are requested.
@immutable
class PlacesProxyRequest {
  const PlacesProxyRequest({
    required this.operation,
    required this.method,
    required this.uri,
  });

  /// Places operation being sent through the proxy.
  final PlacesOperation operation;

  /// Uppercase HTTP method.
  final String method;

  /// Final proxy URI. This may contain request parameters and should not be
  /// logged indiscriminately.
  final Uri uri;

  @override
  String toString() =>
      'PlacesProxyRequest(operation: $operation, method: $method, uri: <redacted>)';
}

/// Supplies fresh authentication headers for an outgoing proxy request.
typedef PlacesProxyAuthenticationProvider =
    FutureOr<Map<String, String>> Function(PlacesProxyRequest request);

@immutable
/// Keyless proxy endpoints and their client-to-proxy authentication hook.
class PlacesProxyConfiguration {
  const PlacesProxyConfiguration({
    required this.placesEndpoint,
    this.timeZoneEndpoint,
    this.authentication,
  });

  /// Base endpoint to which Places API v1 resource paths are appended.
  final Uri placesEndpoint;

  /// Exact Time Zone proxy endpoint. Required only for Time Zone operations.
  final Uri? timeZoneEndpoint;

  /// Optional per-request client-to-proxy authentication provider.
  final PlacesProxyAuthenticationProvider? authentication;

  void validate() {
    _validateProxyEndpoint(placesEndpoint, name: 'placesEndpoint');
    final timeZoneEndpoint = this.timeZoneEndpoint;
    if (timeZoneEndpoint != null) {
      _validateProxyEndpoint(timeZoneEndpoint, name: 'timeZoneEndpoint');
    }
  }

  @override
  String toString() =>
      'PlacesProxyConfiguration(placesEndpoint: <redacted>, '
      'timeZoneEndpoint: ${timeZoneEndpoint == null ? 'none' : '<redacted>'}, '
      'authentication: ${authentication == null ? 'none' : '<redacted>'})';
}

@immutable
/// Cross-platform behavioral options for `PlacesClient`.
class PlacesClientOptions {
  const PlacesClientOptions({
    this.requestTimeout = const Duration(seconds: 15),
    this.httpClientOwnership = PlacesHttpClientOwnership.caller,
    this.applicationIdentity,
    this.web = const PlacesWebOptions(),
  });

  /// Maximum duration for an individual HTTP or JavaScript operation.
  final Duration requestTimeout;

  /// Ownership used only when an HTTP client is injected by the caller.
  ///
  /// Internally created clients are always owned and closed by the package.
  final PlacesHttpClientOwnership httpClientOwnership;

  /// Optional mobile application identity for direct REST key restrictions.
  ///
  /// These headers are never sent to a configured proxy.
  final PlacesApplicationIdentity? applicationIdentity;

  /// Browser-specific script loading and HTTP fallback behavior.
  final PlacesWebOptions web;
}

void _validateProxyEndpoint(Uri endpoint, {required String name}) {
  final isLoopback =
      endpoint.host == 'localhost' ||
      endpoint.host == '127.0.0.1' ||
      endpoint.host == '::1';
  final hasValidScheme =
      endpoint.scheme == 'https' || (endpoint.scheme == 'http' && isLoopback);
  if (!endpoint.isAbsolute || endpoint.host.isEmpty || !hasValidScheme) {
    throw PlacesException.configuration(
      '$name must be an absolute HTTPS URI (HTTP is allowed only for loopback development).',
      code: 'invalid_proxy_endpoint',
    );
  }
  if (endpoint.hasQuery ||
      endpoint.hasFragment ||
      endpoint.userInfo.isNotEmpty) {
    throw PlacesException.configuration(
      '$name cannot include credentials, query parameters, or a fragment.',
      code: 'unsafe_proxy_endpoint',
    );
  }
}
