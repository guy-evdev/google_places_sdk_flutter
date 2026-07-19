@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/places_web_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('direct compatibility policy permits Google HTTP operations', () async {
    late http.Request sentRequest;
    final backend = PlacesWebBackend(
      apiKey: 'browser-key',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return http.Response(
          '{"name":"places/p/photos/x/media",'
          '"photoUri":"https://example.test/photo"}',
          200,
        );
      }),
    );

    await backend.fetchPhotoMedia(
      const PhotoMediaRequest(name: 'places/p/photos/x', maxWidthPx: 100),
    );

    expect(sentRequest.url.host, 'places.googleapis.com');
    expect(sentRequest.url.queryParameters['key'], 'browser-key');
    await backend.close();
  });

  test(
    'keyless web proxy routes autocomplete over authenticated REST',
    () async {
      late http.Request sentRequest;
      final backend = PlacesWebBackend(
        apiKey: '',
        proxyConfiguration: PlacesProxyConfiguration(
          placesEndpoint: Uri.parse('https://proxy.example.test/places/v1'),
          authentication: (_) => <String, String>{
            'Authorization': 'Bearer browser-token',
          },
        ),
        options: const PlacesClientOptions(
          web: PlacesWebOptions(
            fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly,
          ),
        ),
        httpClient: MockClient((request) async {
          sentRequest = request;
          return http.Response(
            jsonEncode(<String, Object?>{
              'suggestions': <Object?>[
                <String, Object?>{
                  'placePrediction': <String, Object?>{
                    'placeId': 'place-1',
                    'text': <String, Object?>{'text': 'Coffee Lab'},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final suggestions = await backend.autocompleteSuggestions(
        const AutocompleteRequest(input: 'coffee'),
      );

      expect(suggestions.single, isA<PlaceSuggestion>());
      expect(sentRequest.url.path, '/places/v1/places:autocomplete');
      expect(sentRequest.headers['Authorization'], 'Bearer browser-token');
      expect(sentRequest.headers, isNot(contains('X-Goog-Api-Key')));
      expect(sentRequest.url.queryParameters, isNot(contains('key')));
      await backend.close();
    },
  );

  test('proxy-only web policy rejects direct HTTP operations', () async {
    final backend = PlacesWebBackend(
      apiKey: 'browser-key',
      options: const PlacesClientOptions(
        web: PlacesWebOptions(
          fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly,
        ),
      ),
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    await expectLater(
      backend.fetchPhotoMedia(
        const PhotoMediaRequest(name: 'places/p/photos/x', maxWidthPx: 100),
      ),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'web_proxy_required',
        ),
      ),
    );
    await backend.close();
  });

  test('disabled web policy rejects proxy HTTP operations', () async {
    final backend = PlacesWebBackend(
      apiKey: '',
      proxyConfiguration: PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://proxy.example.test/v1'),
      ),
      options: const PlacesClientOptions(
        web: PlacesWebOptions(fallbackPolicy: PlacesWebFallbackPolicy.disabled),
      ),
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    await expectLater(
      backend.searchTextPage(const TextSearchRequest(textQuery: 'coffee')),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'web_http_disabled',
        ),
      ),
    );
    await backend.close();
  });

  test('web backend rejects mobile application identity', () {
    expect(
      () => PlacesWebBackend(
        apiKey: 'browser-key',
        options: const PlacesClientOptions(
          applicationIdentity: PlacesApplicationIdentity.ios(
            'com.example.places',
          ),
        ),
      ),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'unsupported_web_application_identity',
        ),
      ),
    );
  });
}
