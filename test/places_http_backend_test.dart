import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/places_http_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this.delegate);

  final http.Client delegate;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      delegate.send(request);

  @override
  void close() {
    closed = true;
    delegate.close();
  }
}

class _AbortTrackingClient extends http.BaseClient {
  bool sawAbortableRequest = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    sawAbortableRequest = request is http.AbortableRequest;
    final trigger = (request as http.AbortableRequest).abortTrigger!;
    await trigger;
    throw http.RequestAbortedException(request.url);
  }
}

void main() {
  test('caller cancellation aborts the underlying HTTP request', () async {
    final httpClient = _AbortTrackingClient();
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: httpClient,
    );
    final cancellationToken = PlacesCancellationToken();

    final operation = backend.autocomplete(
      const AutocompleteRequest(input: 'coffee'),
      cancellationToken: cancellationToken,
    );
    await Future<void>.delayed(Duration.zero);
    cancellationToken.cancel();

    await expectLater(
      operation,
      throwsA(
        isA<PlacesException>()
            .having((error) => error.kind, 'kind', PlacesErrorKind.cancellation)
            .having((error) => error.code, 'code', 'request_cancelled'),
      ),
    );
    expect(httpClient.sawAbortableRequest, isTrue);
  });

  test('adds direct Android application restriction headers', () async {
    late http.Request sentRequest;
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      options: const PlacesClientOptions(
        applicationIdentity: PlacesApplicationIdentity.android(
          'com.example.places',
          'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
        ),
      ),
      httpClient: MockClient((request) async {
        sentRequest = request;
        return http.Response('{"places": []}', 200);
      }),
    );

    await backend.searchText(const TextSearchRequest(textQuery: 'coffee'));

    expect(sentRequest.headers['X-Goog-Api-Key'], 'api-key');
    expect(sentRequest.headers['X-Android-Package'], 'com.example.places');
    expect(
      sentRequest.headers['X-Android-Cert'],
      'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
    );
  });

  test('authenticated proxy requests never forward a Google key', () async {
    final sentRequests = <http.Request>[];
    var authenticationCalls = 0;
    PlacesProxyRequest? authenticationRequest;
    final backend = PlacesHttpBackend(
      apiKey: 'must-not-be-forwarded',
      proxyConfiguration: PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://proxy.example.test/maps/places/v1'),
        authentication: (request) {
          authenticationRequest = request;
          authenticationCalls++;
          return <String, String>{
            'Authorization': 'Bearer app-token-$authenticationCalls',
          };
        },
      ),
      httpClient: MockClient((request) async {
        sentRequests.add(request);
        return http.Response('{"places": []}', 200);
      }),
    );

    await backend.searchText(const TextSearchRequest(textQuery: 'coffee'));
    await backend.searchText(const TextSearchRequest(textQuery: 'bakery'));

    expect(
      sentRequests.first.url.toString(),
      'https://proxy.example.test/maps/places/v1/places:searchText',
    );
    for (final request in sentRequests) {
      expect(request.url.queryParameters, isNot(contains('key')));
      expect(request.headers, isNot(contains('X-Goog-Api-Key')));
    }
    expect(sentRequests.first.headers['Authorization'], 'Bearer app-token-1');
    expect(sentRequests.last.headers['Authorization'], 'Bearer app-token-2');
    expect(authenticationCalls, 2);
    expect(authenticationRequest!.method, 'POST');
    expect(authenticationRequest!.operation, PlacesOperation.textSearch);
  });

  test('keyless proxy photo and Time Zone requests omit Google keys', () async {
    final requests = <http.Request>[];
    final backend = PlacesHttpBackend(
      apiKey: '',
      proxyConfiguration: PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://proxy.example.test/places/v1'),
        timeZoneEndpoint: Uri.parse('https://proxy.example.test/timezone'),
        authentication: (_) => <String, String>{'X-App-Token': 'token'},
      ),
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/timezone') {
          return http.Response(
            '{"status":"OK","timeZoneId":"Etc/UTC",'
            '"timeZoneName":"UTC","rawOffset":0,"dstOffset":0}',
            200,
          );
        }
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
    await backend.fetchTimeZone(
      const TimeZoneRequest(
        location: PlaceCoordinates(latitude: 1, longitude: 2),
      ),
    );

    expect(requests, hasLength(2));
    for (final request in requests) {
      expect(request.url.queryParameters, isNot(contains('key')));
      expect(request.headers, isNot(contains('X-Goog-Api-Key')));
      expect(request.headers['X-App-Token'], 'token');
    }
    expect(requests.last.url.path, '/timezone');
  });

  test('proxy authentication cannot override credential headers', () async {
    final backend = PlacesHttpBackend(
      apiKey: '',
      proxyConfiguration: PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://proxy.example.test/v1'),
        authentication: (_) => <String, String>{
          'X-Goog-Api-Key': 'must-not-pass',
        },
      ),
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    await expectLater(
      backend.searchText(const TextSearchRequest(textQuery: 'coffee')),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'unsafe_proxy_authentication_header',
        ),
      ),
    );
  });

  test(
    'proxy authentication is bounded and redacts callback failures',
    () async {
      final timeoutBackend = PlacesHttpBackend(
        apiKey: '',
        proxyConfiguration: PlacesProxyConfiguration(
          placesEndpoint: Uri.parse('https://proxy.example.test/v1'),
          authentication: (_) async {
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return <String, String>{};
          },
        ),
        options: const PlacesClientOptions(
          requestTimeout: Duration(milliseconds: 1),
        ),
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
      await expectLater(
        timeoutBackend.searchText(const TextSearchRequest(textQuery: 'coffee')),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.kind,
            'kind',
            PlacesErrorKind.timeout,
          ),
        ),
      );

      final failingBackend = PlacesHttpBackend(
        apiKey: '',
        proxyConfiguration: PlacesProxyConfiguration(
          placesEndpoint: Uri.parse('https://proxy.example.test/v1'),
          authentication: (_) => throw StateError('secret callback detail'),
        ),
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
      await expectLater(
        failingBackend.searchText(const TextSearchRequest(textQuery: 'coffee')),
        throwsA(
          isA<PlacesException>()
              .having((error) => error.kind, 'kind', PlacesErrorKind.proxy)
              .having(
                (error) => error.toString(),
                'diagnostic',
                isNot(contains('secret callback detail')),
              ),
        ),
      );
    },
  );

  test('legacy proxy URL no longer receives the Google key', () async {
    late http.Request sentRequest;
    final backend = PlacesHttpBackend(
      apiKey: 'must-not-be-forwarded',
      proxyBaseUrl: 'https://proxy.example.test/v1',
      httpClient: MockClient((request) async {
        sentRequest = request;
        return http.Response('{"places": []}', 200);
      }),
    );

    await backend.searchText(const TextSearchRequest(textQuery: 'coffee'));

    expect(sentRequest.headers, isNot(contains('X-Goog-Api-Key')));
    expect(sentRequest.url.queryParameters, isNot(contains('key')));
  });

  test('keyless proxy requires an explicit Time Zone endpoint', () async {
    final backend = PlacesHttpBackend(
      apiKey: '',
      proxyConfiguration: PlacesProxyConfiguration(
        placesEndpoint: Uri.parse('https://proxy.example.test/v1'),
      ),
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );

    await expectLater(
      backend.fetchTimeZone(
        const TimeZoneRequest(
          location: PlaceCoordinates(latitude: 1, longitude: 2),
        ),
      ),
      throwsA(
        isA<PlacesException>().having(
          (error) => error.code,
          'code',
          'missing_proxy_time_zone_endpoint',
        ),
      ),
    );
  });

  test('autocompleteSuggestions parses place and query predictions', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/places:autocomplete');
        expect(
          request.headers['X-Goog-FieldMask'],
          'suggestions.placePrediction.place,'
          'suggestions.placePrediction.placeId,'
          'suggestions.placePrediction.text,'
          'suggestions.placePrediction.structuredFormat.mainText,'
          'suggestions.placePrediction.structuredFormat.secondaryText,'
          'suggestions.placePrediction.distanceMeters,'
          'suggestions.placePrediction.types,'
          'suggestions.queryPrediction.text',
        );
        final body = jsonDecode(request.body) as Map<String, Object?>;
        expect(body['includeQueryPredictions'], isTrue);
        return http.Response(
          jsonEncode(<String, Object?>{
            'suggestions': <Map<String, Object?>>[
              <String, Object?>{
                'placePrediction': <String, Object?>{
                  'placeId': 'place-1',
                  'place': 'places/place-1',
                  'text': <String, Object?>{'text': 'Coffee Lab'},
                },
              },
              <String, Object?>{
                'queryPrediction': <String, Object?>{
                  'text': <String, Object?>{'text': 'coffee near me'},
                },
              },
            ],
          }),
          200,
        );
      }),
    );

    final suggestions = await backend.autocompleteSuggestions(
      const AutocompleteRequest(input: 'coffee', includeQueryPredictions: true),
    );

    expect(suggestions, hasLength(2));
    expect(suggestions.first, isA<PlaceSuggestion>());
    expect(suggestions.last, isA<QuerySuggestion>());
  });

  test(
    'autocomplete remains place-only when query predictions are present',
    () async {
      final backend = PlacesHttpBackend(
        apiKey: 'api-key',
        httpClient: MockClient((request) async {
          expect(
            request.headers['X-Goog-FieldMask'],
            isNot(contains('queryPrediction')),
          );
          return http.Response(
            jsonEncode(<String, Object?>{
              'suggestions': <Map<String, Object?>>[
                <String, Object?>{
                  'placePrediction': <String, Object?>{
                    'placeId': 'place-1',
                    'place': 'places/place-1',
                    'text': <String, Object?>{'text': 'Coffee Lab'},
                  },
                },
                <String, Object?>{
                  'queryPrediction': <String, Object?>{
                    'text': <String, Object?>{'text': 'coffee near me'},
                  },
                },
              ],
            }),
            200,
          );
        }),
      );

      final suggestions = await backend.autocomplete(
        const AutocompleteRequest(input: 'coffee'),
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.placeId, 'place-1');
    },
  );

  test('fetchPhotoMedia builds the expected media request', () async {
    late Uri requestUri;
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode(<String, Object?>{
            'name': 'places/place-1/photos/photo-1/media',
            'photoUri': 'https://example.com/photo.jpg',
          }),
          200,
        );
      }),
    );

    final result = await backend.fetchPhotoMedia(
      const PhotoMediaRequest(
        name: 'places/place-1/photos/photo-1',
        maxWidthPx: 600,
      ),
    );

    expect(requestUri.path, '/v1/places/place-1/photos/photo-1/media');
    expect(requestUri.queryParameters['maxWidthPx'], '600');
    expect(requestUri.queryParameters['skipHttpRedirect'], 'true');
    expect(
      requestUri.queryParameters.containsKey('key'),
      isFalse,
      reason: 'the API key authenticates via X-Goog-Api-Key, not the URL',
    );
    expect(result.photoUri, 'https://example.com/photo.jpg');
  });

  test('fetchPhotoMedia surfaces HTTP errors', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'error': <String, Object?>{'message': 'Invalid photo.'},
          }),
          400,
        );
      }),
    );

    await expectLater(
      backend.fetchPhotoMedia(
        const PhotoMediaRequest(name: 'places/p/photos/x', maxWidthPx: 100),
      ),
      throwsA(
        isA<PlacesException>()
            .having((error) => error.kind, 'kind', PlacesErrorKind.googleApi)
            .having((error) => error.statusCode, 'statusCode', 400)
            .having(
              (error) => error.operation,
              'operation',
              PlacesOperation.photoMedia,
            ),
      ),
    );
  });

  test(
    'normalizes malformed, empty, and non-object success responses',
    () async {
      for (final body in <String>['', '<html>bad gateway</html>', '[]']) {
        final backend = PlacesHttpBackend(
          apiKey: 'api-key',
          httpClient: MockClient((request) async => http.Response(body, 200)),
        );

        await expectLater(
          backend.searchText(const TextSearchRequest(textQuery: 'coffee')),
          throwsA(
            isA<PlacesException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  PlacesErrorKind.googleApi,
                )
                .having(
                  (error) => error.operation,
                  'operation',
                  PlacesOperation.textSearch,
                ),
          ),
        );
      }
    },
  );

  test('classifies malformed proxy responses separately', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      proxyBaseUrl: 'https://proxy.example.test',
      httpClient: MockClient(
        (request) async => http.Response('<html>bad gateway</html>', 502),
      ),
    );

    await expectLater(
      backend.searchText(const TextSearchRequest(textQuery: 'coffee')),
      throwsA(
        isA<PlacesException>()
            .having((error) => error.kind, 'kind', PlacesErrorKind.proxy)
            .having((error) => error.code, 'code', 'malformed_json'),
      ),
    );
  });

  test('normalizes network failures and request timeouts', () async {
    final networkBackend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        throw http.ClientException('private transport details');
      }),
    );
    await expectLater(
      networkBackend.searchText(const TextSearchRequest(textQuery: 'coffee')),
      throwsA(
        isA<PlacesException>()
            .having((error) => error.kind, 'kind', PlacesErrorKind.network)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );

    final timeoutBackend = PlacesHttpBackend(
      apiKey: 'api-key',
      options: const PlacesClientOptions(
        requestTimeout: Duration(milliseconds: 1),
      ),
      httpClient: MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      timeoutBackend.searchText(const TextSearchRequest(textQuery: 'coffee')),
      throwsA(
        isA<PlacesException>()
            .having((error) => error.kind, 'kind', PlacesErrorKind.timeout)
            .having((error) => error.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('reports missing keys and invalid timeout configuration', () async {
    final missingKeyBackend = PlacesHttpBackend(
      apiKey: '',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
    await expectLater(
      missingKeyBackend.searchText(
        const TextSearchRequest(textQuery: 'coffee'),
      ),
      throwsA(
        isA<PlacesException>()
            .having(
              (error) => error.kind,
              'kind',
              PlacesErrorKind.configuration,
            )
            .having(
              (error) => error.operation,
              'operation',
              PlacesOperation.textSearch,
            ),
      ),
    );

    final invalidTimeoutBackend = PlacesHttpBackend(
      apiKey: 'api-key',
      options: const PlacesClientOptions(requestTimeout: Duration.zero),
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
    await expectLater(
      invalidTimeoutBackend.searchText(
        const TextSearchRequest(textQuery: 'coffee'),
      ),
      throwsA(
        isA<PlacesException>()
            .having(
              (error) => error.kind,
              'kind',
              PlacesErrorKind.configuration,
            )
            .having((error) => error.code, 'code', 'invalid_request_timeout'),
      ),
    );
  });

  test(
    'closes injected HTTP clients only when ownership is transferred',
    () async {
      final callerOwned = _CloseTrackingClient(
        MockClient((request) async => http.Response('{}', 200)),
      );
      final packageOwned = _CloseTrackingClient(
        MockClient((request) async => http.Response('{}', 200)),
      );
      final callerOwnedBackend = PlacesHttpBackend(
        apiKey: 'api-key',
        httpClient: callerOwned,
      );
      final packageOwnedBackend = PlacesHttpBackend(
        apiKey: 'api-key',
        options: const PlacesClientOptions(
          httpClientOwnership: PlacesHttpClientOwnership.placesClient,
        ),
        httpClient: packageOwned,
      );

      await callerOwnedBackend.close();
      await packageOwnedBackend.close();

      expect(callerOwned.closed, isFalse);
      expect(packageOwned.closed, isTrue);
      callerOwned.close();
    },
  );

  test('fetchTimeZone builds the expected Google Time Zone request', () async {
    late Uri requestUri;
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      timeZoneBaseUrl: 'https://example.com/timezone',
      httpClient: MockClient((request) async {
        requestUri = request.url;
        return http.Response(
          jsonEncode(<String, Object?>{
            'dstOffset': 3600,
            'rawOffset': -18000,
            'timeZoneId': 'America/New_York',
            'timeZoneName': 'Eastern Daylight Time',
            'status': 'OK',
          }),
          200,
        );
      }),
    );

    final result = await backend.fetchTimeZone(
      TimeZoneRequest(
        location: const PlaceCoordinates(
          latitude: 40.7128,
          longitude: -74.0060,
        ),
        timestamp: DateTime.utc(2026, 4, 15, 12),
        languageCode: 'en',
      ),
    );

    expect(
      requestUri.toString(),
      startsWith('https://example.com/timezone/json?'),
    );
    expect(requestUri.queryParameters['location'], '40.7128,-74.006');
    expect(requestUri.queryParameters['timestamp'], '1776254400');
    expect(requestUri.queryParameters['key'], 'api-key');
    expect(requestUri.queryParameters['language'], 'en');
    expect(result.timeZoneId, 'America/New_York');
  });

  test('fetchTimeZone throws when Google returns a non-OK status', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'ZERO_RESULTS',
            'errorMessage': 'No time zone data for this point.',
          }),
          200,
        );
      }),
    );

    expect(
      () => backend.fetchTimeZone(
        const TimeZoneRequest(
          location: PlaceCoordinates(latitude: 0, longitude: 0),
        ),
      ),
      throwsA(isA<PlacesException>()),
    );
  });

  test(
    'searchTextPage preserves pagination metadata and request fields',
    () async {
      final backend = PlacesHttpBackend(
        apiKey: 'api-key',
        httpClient: MockClient((request) async {
          expect(request.url.path, '/v1/places:searchText');
          expect(
            request.headers['X-Goog-FieldMask'],
            contains('nextPageToken,searchUri'),
          );
          final body = jsonDecode(request.body) as Map<String, Object?>;
          expect(body['pageSize'], 5);
          expect(body['pageToken'], 'page-2');
          expect(body['includeFutureOpeningBusinesses'], isTrue);
          expect(body['priceLevels'], <String>['PRICE_LEVEL_MODERATE']);
          return http.Response(
            jsonEncode(<String, Object?>{
              'places': <Map<String, Object?>>[
                <String, Object?>{'id': 'place-1'},
              ],
              'nextPageToken': 'page-3',
              'searchUri': 'https://www.google.com/maps/search/coffee',
            }),
            200,
          );
        }),
      );

      final page = await backend.searchTextPage(
        const TextSearchRequest(
          textQuery: 'coffee',
          pageSize: 5,
          pageToken: 'page-2',
          priceLevels: <PlacePriceLevel>[PlacePriceLevel.moderate],
          includeFutureOpeningBusinesses: true,
        ),
      );

      expect(page.results.single.id, 'place-1');
      expect(page.nextPageToken, 'page-3');
      expect(page.searchUri, contains('/maps/search/coffee'));
    },
  );

  test('searchText remains a result-list convenience', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{
            'places': <Map<String, Object?>>[
              <String, Object?>{'id': 'place-1'},
            ],
            'nextPageToken': 'ignored-by-convenience',
          }),
          200,
        );
      }),
    );

    final results = await backend.searchText(
      const TextSearchRequest(textQuery: 'coffee'),
    );

    expect(results.single.id, 'place-1');
  });

  test('no credential appears in any request URI, for any operation', () async {
    const apiKey = 'super-secret-api-key';
    final sentUris = <Uri>[];
    final backend = PlacesHttpBackend(
      apiKey: apiKey,
      timeZoneBaseUrl: 'https://timezone.example.test/tz',
      httpClient: MockClient((request) async {
        sentUris.add(request.url);
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'OK',
            'name': 'places/place-1/photos/photo-1/media',
            'photoUri': 'https://example.com/photo.jpg',
            'dstOffset': 0,
            'rawOffset': 0,
            'timeZoneId': 'UTC',
            'timeZoneName': 'Coordinated Universal Time',
            'id': 'place-1',
            'places': <Object?>[],
            'suggestions': <Object?>[],
          }),
          200,
        );
      }),
    );

    await backend.autocomplete(const AutocompleteRequest(input: 'coffee'));
    await backend.fetchPlace(const PlaceDetailsRequest(placeId: 'place-1'));
    await backend.fetchPhotoMedia(
      const PhotoMediaRequest(
        name: 'places/place-1/photos/photo-1',
        maxWidthPx: 400,
      ),
    );
    await backend.searchText(const TextSearchRequest(textQuery: 'coffee'));
    await backend.searchTextPage(const TextSearchRequest(textQuery: 'coffee'));
    await backend.searchNearby(
      NearbySearchRequest(
        locationRestriction: LocationRestriction.circle(
          center: const PlaceCoordinates(latitude: 1, longitude: 2),
          radiusMeters: 500,
        ),
      ),
    );

    expect(sentUris, hasLength(6));
    for (final uri in sentUris) {
      expect(
        uri.toString(),
        isNot(contains(apiKey)),
        reason:
            'Places operations authenticate with the X-Goog-Api-Key header. A '
            'key in the URI is recorded by proxy logs, CDN logs, and browser '
            'history. Offending request: $uri',
      );
    }
  });

  test('the Time Zone API is the only operation that keys the URI', () async {
    // Google's Time Zone API has no header authentication, so this one is
    // unavoidable. It is asserted explicitly so the exception stays visible.
    late Uri sentUri;
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        sentUri = request.url;
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'OK',
            'dstOffset': 0,
            'rawOffset': 0,
            'timeZoneId': 'UTC',
            'timeZoneName': 'Coordinated Universal Time',
          }),
          200,
        );
      }),
    );

    await backend.fetchTimeZone(
      const TimeZoneRequest(
        location: PlaceCoordinates(latitude: 1, longitude: 2),
      ),
    );

    expect(sentUri.queryParameters['key'], 'api-key');
  });

  test('a custom timeZoneBaseUrl keeps its own query parameters', () async {
    late Uri sentUri;
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      timeZoneBaseUrl: 'https://gateway.example.test/tz?route=timezone',
      httpClient: MockClient((request) async {
        sentUri = request.url;
        return http.Response(
          jsonEncode(<String, Object?>{
            'status': 'OK',
            'dstOffset': 0,
            'rawOffset': 0,
            'timeZoneId': 'UTC',
            'timeZoneName': 'Coordinated Universal Time',
          }),
          200,
        );
      }),
    );

    await backend.fetchTimeZone(
      const TimeZoneRequest(
        location: PlaceCoordinates(latitude: 1, longitude: 2),
      ),
    );

    expect(sentUri.path, '/tz/json');
    expect(sentUri.queryParameters['route'], 'timezone');
    // Number formatting differs between the VM and dart2js, so assert the
    // parameter survived rather than its exact rendering.
    expect(sentUri.queryParameters, contains('location'));
    expect(sentUri.queryParameters, contains('timestamp'));
  });

  test('a reused cancellation token does not accumulate listeners', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode(<String, Object?>{'suggestions': <Object?>[]}),
          200,
        );
      }),
    );
    final cancellationToken = PlacesCancellationToken();

    for (var i = 0; i < 25; i++) {
      await backend.autocomplete(
        const AutocompleteRequest(input: 'coffee'),
        cancellationToken: cancellationToken,
      );
    }

    expect(
      cancellationToken.debugListenerCount,
      0,
      reason:
          'each request must detach its cancellation listener, or a long-lived '
          'token retains one closure per request issued',
    );
  });
}
