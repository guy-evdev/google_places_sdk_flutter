import 'package:http/http.dart' as http;

import 'internal/backend.dart';
import 'internal/create_backend.dart';
import 'models/place_models.dart';

/// Cross-platform client for Google Places API (New).
///
/// On Android, iOS, macOS, Windows, and Linux this uses HTTP requests to the
/// Places API (New). On web it uses the Google Maps JavaScript Places library.
///
/// Example:
/// ```dart
/// final client = PlacesClient(apiKey: 'your-key');
/// final suggestions = await client.autocomplete(
///   const AutocompleteRequest(input: 'coffee'),
/// );
/// ```
class PlacesClient {
  PlacesClient({
    required this.apiKey,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
    http.Client? httpClient,
  }) : _backend = createPlacesBackend(
         apiKey: apiKey,
         proxyBaseUrl: proxyBaseUrl,
         timeZoneBaseUrl: timeZoneBaseUrl,
         httpClient: httpClient,
       );

  PlacesClient.testing({
    required this.apiKey,
    required PlacesBackend backend,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
  }) : _backend = backend;

  final String apiKey;
  final String? proxyBaseUrl;
  final String? timeZoneBaseUrl;
  final PlacesBackend _backend;

  /// Fetches autocomplete suggestions for the supplied request.
  Future<List<PlaceSuggestion>> autocomplete(AutocompleteRequest request) =>
      _backend.autocomplete(request);

  /// Resolves a place id into rich place details.
  ///
  /// This is the canonical standalone place-details API for the package.
  Future<PlaceData> fetchPlace(PlaceDetailsRequest request) =>
      _backend.fetchPlace(request);

  /// Resolves a place id into rich place details without requiring a suggestion.
  ///
  /// This is a convenience wrapper around [fetchPlace] for place-id-first
  /// workflows.
  Future<PlaceData> fetchPlaceById(
    String placeId, {
    Set<PlaceField> fields = PlaceFieldPresets.recommended,
    String? languageCode,
    String? regionCode,
    AutocompleteSessionToken? sessionToken,
  }) => _backend.fetchPlace(
    PlaceDetailsRequest(
      placeId: placeId,
      fields: fields,
      languageCode: languageCode,
      regionCode: regionCode,
      sessionToken: sessionToken,
    ),
  );

  /// Resolves time-zone metadata for geographic coordinates.
  ///
  /// This uses Google Time Zone API, which is separate from Places API and may
  /// be billed separately.
  Future<PlaceTimeZoneData> fetchTimeZone(TimeZoneRequest request) =>
      _backend.fetchTimeZone(request);

  /// Resolves time-zone metadata from [place] coordinates.
  ///
  /// Throws [PlacesException] if [place] does not include coordinates.
  Future<PlaceTimeZoneData> fetchTimeZoneForPlace(
    PlaceData place, {
    DateTime? timestamp,
    String? languageCode,
  }) => _backend.fetchTimeZone(
    TimeZoneRequest.fromPlace(
      place,
      timestamp: timestamp,
      languageCode: languageCode,
    ),
  );

  /// Searches for places by free-text query.
  Future<List<PlaceData>> searchText(TextSearchRequest request) =>
      _backend.searchText(request);

  /// Searches for places near a geographic restriction.
  Future<List<PlaceData>> searchNearby(NearbySearchRequest request) =>
      _backend.searchNearby(request);

  /// Releases backend resources held by this client.
  Future<void> close() => _backend.close();
}
