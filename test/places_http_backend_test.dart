import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';
import 'package:google_places_autocomplete/src/internal/places_http_backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
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
