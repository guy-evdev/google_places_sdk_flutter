import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';

class _RecordingBackend implements PlacesBackend {
  PlaceDetailsRequest? lastPlaceRequest;
  TimeZoneRequest? lastTimeZoneRequest;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request,
  ) async => const <PlaceSuggestion>[];

  @override
  Future<void> close() async {}

  @override
  Future<PlaceData> fetchPlace(PlaceDetailsRequest request) async {
    lastPlaceRequest = request;
    return const PlaceData(id: 'place-1');
  }

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(TimeZoneRequest request) async {
    lastTimeZoneRequest = request;
    return PlaceTimeZoneData(
      dstOffset: Duration.zero,
      rawOffset: Duration.zero,
      timeZoneId: 'UTC',
      timeZoneName: 'Coordinated Universal Time',
      timestamp: request.timestamp ?? DateTime.utc(2026, 4, 15),
    );
  }

  @override
  Future<List<PlaceData>> searchNearby(NearbySearchRequest request) async =>
      const <PlaceData>[];

  @override
  Future<List<PlaceData>> searchText(TextSearchRequest request) async =>
      const <PlaceData>[];
}

void main() {
  test('fetchPlaceById forwards a place-id-only details request', () async {
    final backend = _RecordingBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final sessionToken = AutocompleteSessionToken.fromValue('session');

    await client.fetchPlaceById(
      'abc123',
      fields: PlaceFieldPresets.rich,
      languageCode: 'en',
      regionCode: 'us',
      sessionToken: sessionToken,
    );

    expect(backend.lastPlaceRequest, isNotNull);
    expect(backend.lastPlaceRequest!.placeId, 'abc123');
    expect(backend.lastPlaceRequest!.fields, PlaceFieldPresets.rich);
    expect(backend.lastPlaceRequest!.languageCode, 'en');
    expect(backend.lastPlaceRequest!.regionCode, 'us');
    expect(backend.lastPlaceRequest!.sessionToken, sessionToken);
  });

  test(
    'fetchTimeZoneForPlace builds the request from place coordinates',
    () async {
      final backend = _RecordingBackend();
      final client = PlacesClient.testing(apiKey: 'test', backend: backend);
      final timestamp = DateTime.utc(2026, 4, 15, 9);

      await client.fetchTimeZoneForPlace(
        const PlaceData(
          id: 'place-1',
          location: PlaceCoordinates(latitude: 32.08, longitude: 34.78),
        ),
        timestamp: timestamp,
        languageCode: 'he',
      );

      expect(backend.lastTimeZoneRequest, isNotNull);
      expect(backend.lastTimeZoneRequest!.location.latitude, 32.08);
      expect(backend.lastTimeZoneRequest!.timestamp, timestamp);
      expect(backend.lastTimeZoneRequest!.languageCode, 'he');
    },
  );
}
