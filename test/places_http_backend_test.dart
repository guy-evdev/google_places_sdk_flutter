import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/places_http_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('autocompleteSuggestions parses place and query predictions', () async {
    final backend = PlacesHttpBackend(
      apiKey: 'api-key',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/places:autocomplete');
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
        const AutocompleteRequest(
          input: 'coffee',
          includeQueryPredictions: true,
        ),
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
    expect(requestUri.queryParameters['key'], 'api-key');
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

    expect(
      () => backend.fetchPhotoMedia(
        const PhotoMediaRequest(name: 'places/p/photos/x', maxWidthPx: 100),
      ),
      throwsA(isA<PlacesException>()),
    );
  });

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
}
