import '../models/place_models.dart';
import '../places_cancellation_token.dart';

/// Transport-independent contract for every Places operation the client performs.
///
/// Methods taking a cancellation token honour it when one is given.
abstract interface class PlacesBackend {
  /// Runs an autocomplete request and returns place suggestions.
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Runs an autocomplete request and returns place and query suggestions.
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Ends the autocomplete session identified by [token].
  Future<void> endAutocompleteSession(AutocompleteSessionToken token);

  /// Fetches the details of one place.
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Fetches the media for one place photo.
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Fetches the time zone for a location.
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Runs a text search and returns the matching places.
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Runs a text search and returns one page of results.
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Runs a nearby search and returns the matching places.
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  });

  /// Releases resources held by the backend.
  Future<void> close();
}
