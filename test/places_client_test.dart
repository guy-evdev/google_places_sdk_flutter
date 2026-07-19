import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient()
    : _delegate = MockClient(
        (request) async => http.Response('{"places": []}', 200),
      );

  final http.Client _delegate;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _delegate.send(request);

  @override
  void close() {
    closed = true;
    _delegate.close();
  }
}

class _RecordingBackend implements PlacesBackend {
  PlaceDetailsRequest? lastPlaceRequest;
  TimeZoneRequest? lastTimeZoneRequest;
  TextSearchRequest? lastTextSearchPageRequest;
  AutocompleteSessionToken? endedSessionToken;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceSuggestion>[];

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <AutocompleteSuggestion>[];

  @override
  Future<void> close() async {}

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {
    endedSessionToken = token;
  }

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    lastPlaceRequest = request;
    return const PlaceData(id: 'place-1');
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const PlacePhotoMedia(
    name: 'places/place-1/photos/photo-1/media',
    photoUri: 'https://example.com/photo.jpg',
  );

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
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
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceData>[];

  @override
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceData>[];

  @override
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    lastTextSearchPageRequest = request;
    return TextSearchPage(
      results: const <PlaceData>[PlaceData(id: 'place-1')],
      nextPageToken: 'next-token',
      searchUri: 'https://www.google.com/maps/search/coffee',
    );
  }
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

  test('production client forwards injected HTTP ownership options', () async {
    final callerOwned = _CloseTrackingClient();
    final packageOwned = _CloseTrackingClient();
    if (kIsWeb) {
      expect(
        () => PlacesClient(apiKey: 'test', httpClient: callerOwned),
        throwsA(
          isA<PlacesException>().having(
            (error) => error.code,
            'code',
            'unsupported_web_http_client',
          ),
        ),
      );
      callerOwned.close();
      packageOwned.close();
      return;
    }
    final callerClient = PlacesClient(apiKey: 'test', httpClient: callerOwned);
    final owningClient = PlacesClient(
      apiKey: 'test',
      httpClient: packageOwned,
      options: const PlacesClientOptions(
        httpClientOwnership: PlacesHttpClientOwnership.placesClient,
      ),
    );

    await callerClient.close();
    await owningClient.close();

    expect(callerOwned.closed, isFalse);
    expect(packageOwned.closed, isTrue);
    callerOwned.close();
  });

  test('proxy constructor is keyless and defaults web to proxy-only', () async {
    final client = PlacesClient.proxy(
      placesEndpoint: Uri.parse('https://proxy.example.test/places/v1'),
      timeZoneEndpoint: Uri.parse('https://proxy.example.test/timezone'),
      authentication: (_) => <String, String>{
        'Authorization': 'Bearer app-token',
      },
    );

    expect(client.apiKey, isEmpty);
    expect(client.proxyConfiguration, isNotNull);
    expect(
      client.options.web.fallbackPolicy,
      PlacesWebFallbackPolicy.proxyOnly,
    );
    expect(client.proxyConfiguration.toString(), isNot(contains('app-token')));
    await client.close();
  });

  test('searchTextPage preserves page metadata from the backend', () async {
    final backend = _RecordingBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    const request = TextSearchRequest(textQuery: 'coffee', pageSize: 5);

    final page = await client.searchTextPage(request);

    expect(backend.lastTextSearchPageRequest, same(request));
    expect(page.results.single.id, 'place-1');
    expect(page.nextPageToken, 'next-token');
    expect(page.searchUri, contains('/maps/search/coffee'));
  });

  test(
    'endAutocompleteSession delegates session cleanup to the backend',
    () async {
      final backend = _RecordingBackend();
      final client = PlacesClient.testing(apiKey: 'test', backend: backend);
      final token = AutocompleteSessionToken.fromValue('session-to-end');

      await client.endAutocompleteSession(token);

      expect(backend.endedSessionToken, same(token));
    },
  );
}
