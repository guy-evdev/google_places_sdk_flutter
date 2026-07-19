import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

void main() {
  group('PlacesApplicationIdentity', () {
    test('builds Android restriction headers and redacts the certificate', () {
      const identity = PlacesApplicationIdentity.android(
        'com.example.places',
        'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
      );

      expect(identity.headers, <String, String>{
        'X-Android-Package': 'com.example.places',
        'X-Android-Cert':
            'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
      });
      expect(identity.toString(), isNot(contains('BB:0D')));
    });

    test('builds iOS restriction headers', () {
      const identity = PlacesApplicationIdentity.ios('com.example.places-app');

      expect(identity.headers, <String, String>{
        'X-Ios-Bundle-Identifier': 'com.example.places-app',
      });
    });

    test('rejects invalid application identifiers and fingerprints', () {
      expect(
        () => const PlacesApplicationIdentity.android(
          'not a package',
          'BB:0D',
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => const PlacesApplicationIdentity.ios('invalid').validate(),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.code,
            'code',
            'invalid_ios_bundle_identifier',
          ),
        ),
      );
    });
  });

  group('PlacesProxyConfiguration', () {
    test('accepts HTTPS and loopback development endpoints', () {
      PlacesProxyConfiguration(
        placesEndpoint: Uri(scheme: 'https', host: 'proxy.example', path: 'v1'),
        timeZoneEndpoint: Uri(
          scheme: 'http',
          host: 'localhost',
          port: 8080,
          path: 'timezone',
        ),
      ).validate();
    });

    test('rejects insecure or credential-bearing endpoints', () {
      for (final endpoint in <Uri>[
        Uri.parse('http://proxy.example/v1'),
        Uri.parse('https://user:secret@proxy.example/v1'),
        Uri.parse('https://proxy.example/v1?key=secret'),
        Uri.parse('/relative'),
      ]) {
        expect(
          () => PlacesProxyConfiguration(placesEndpoint: endpoint).validate(),
          throwsA(isA<PlacesException>()),
        );
      }
    });

    test('redacts endpoints and authentication from diagnostics', () {
      final configuration = PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://secret.example/private'),
        authentication: (_) => <String, String>{
          'Authorization': 'Bearer secret',
        },
      );

      expect(configuration.toString(), isNot(contains('secret.example')));
      expect(configuration.toString(), isNot(contains('Bearer secret')));
    });
  });

  test('web options validate initialization timeout and CSP nonce', () {
    expect(
      () => const PlacesWebOptions(
        initializationTimeout: Duration.zero,
      ).validate(),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'invalid_web_initialization_timeout',
        ),
      ),
    );
    expect(
      () => const PlacesWebOptions(cspNonce: '').validate(),
      throwsA(isA<PlacesException>()),
    );
    const PlacesWebOptions(
      versionChannel: PlacesWebVersionChannel.quarterly,
      cspNonce: 'nonce-value',
      fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly,
    ).validate();
  });

  test('proxy request diagnostics redact the URI', () {
    final request = PlacesProxyRequest(
      operation: PlacesOperation.autocomplete,
      method: 'POST',
      uri: Uri.parse('https://proxy.example/v1?sessionToken=secret'),
    );

    expect(request.toString(), isNot(contains('secret')));
    expect(request.toString(), contains('autocomplete'));
  });
}
