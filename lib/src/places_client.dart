import 'package:http/http.dart' as http;

import 'internal/backend.dart';
import 'internal/create_backend.dart';
import 'models/place_models.dart';
import 'places_cancellation_token.dart';
import 'places_client_options.dart';

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
  /// Creates a production client that talks to Google Places services.
  PlacesClient({
    required this.apiKey,
    this.proxyConfiguration,
    @Deprecated(
      'Use proxyConfiguration with Uri endpoints, or PlacesClient.proxy(). '
      'The string proxyBaseUrl parameter is deprecated in 0.6.0.',
    )
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
    this.options = const PlacesClientOptions(),
    http.Client? httpClient,
  }) : _backend = createPlacesBackend(
         apiKey: apiKey,
         proxyConfiguration: proxyConfiguration,
         proxyBaseUrl: proxyBaseUrl,
         timeZoneBaseUrl: timeZoneBaseUrl,
         options: options,
         httpClient: httpClient,
       );

  /// Creates a keyless client that sends all supported operations to a proxy.
  ///
  /// The proxy must add its Google Maps Platform credentials server-side. This
  /// client never accepts, appends, or forwards a Google API key. Google
  /// recommends authenticating every client request to the proxy.
  PlacesClient.proxy({
    required Uri placesEndpoint,
    Uri? timeZoneEndpoint,
    PlacesProxyAuthenticationProvider? authentication,
    this.options = const PlacesClientOptions(
      web: PlacesWebOptions(fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly),
    ),
    http.Client? httpClient,
  }) : apiKey = '',
       proxyConfiguration = PlacesProxyConfiguration(
         placesEndpoint: placesEndpoint,
         timeZoneEndpoint: timeZoneEndpoint,
         authentication: authentication,
       ),
       // ignore: deprecated_member_use_from_same_package
       proxyBaseUrl = null,
       timeZoneBaseUrl = null,
       _backend = createPlacesBackend(
         apiKey: '',
         proxyConfiguration: PlacesProxyConfiguration(
           placesEndpoint: placesEndpoint,
           timeZoneEndpoint: timeZoneEndpoint,
           authentication: authentication,
         ),
         options: options,
         httpClient: httpClient,
       );

  /// Creates a client wired to a custom backend for tests.
  ///
  /// **Not usable from outside this package today.** It requires a
  /// `PlacesBackend`, which is an internal type that the package barrel does
  /// not export, so consumers cannot name it without importing a `src/` path
  /// and tripping the `implementation_imports` lint.
  ///
  /// A supported extension point — a public `PlacesTransport` with
  /// `PlacesClient.custom(transport:)` — is planned for `0.9.0`. Until then,
  /// fake at the `http.Client` level by passing a `MockClient` to the default
  /// [PlacesClient] constructor, which works on every platform except web.
  PlacesClient.testing({
    required this.apiKey,
    required this._backend,
    this.proxyConfiguration,
    this.proxyBaseUrl,
    this.timeZoneBaseUrl,
    this.options = const PlacesClientOptions(),
  });

  /// Google Maps Platform API key used for Places and Time Zone requests.
  final String apiKey;

  /// Optional authenticated, keyless proxy configuration.
  final PlacesProxyConfiguration? proxyConfiguration;

  /// Optional legacy proxy base URL for Places HTTP requests.
  ///
  /// New code should use [proxyConfiguration] or [PlacesClient.proxy]. Google
  /// credentials are not forwarded to this endpoint in `0.6.0`.
  @Deprecated(
    'Use proxyConfiguration with Uri endpoints, or PlacesClient.proxy(). '
    'This string property is deprecated in 0.6.0.',
  )
  final String? proxyBaseUrl;

  /// Optional override for the Time Zone API base URL.
  final String? timeZoneBaseUrl;

  /// Request deadlines, application identity, web behavior, and ownership.
  final PlacesClientOptions options;
  final PlacesBackend _backend;

  /// Fetches autocomplete suggestions for the supplied request.
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.autocomplete(request, cancellationToken: cancellationToken);

  /// Fetches autocomplete place and query suggestions for the supplied request.
  ///
  /// To receive [QuerySuggestion] values, set
  /// [AutocompleteRequest.includeQueryPredictions] to `true`.
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.autocompleteSuggestions(
    request,
    cancellationToken: cancellationToken,
  );

  /// Discards transport state for a concluded or abandoned autocomplete
  /// session.
  ///
  /// Widget flows call this automatically on selection, clearing, abandonment,
  /// replacement, and disposal. Headless flows should call it when a session
  /// ends without a Place Details request.
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) =>
      _backend.endAutocompleteSession(token);

  /// Resolves a place id into rich place details.
  ///
  /// This is the canonical standalone place-details API for the package.
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.fetchPlace(request, cancellationToken: cancellationToken);

  /// Resolves a Places photo resource into a media URI.
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.fetchPhotoMedia(request, cancellationToken: cancellationToken);

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
    PlacesCancellationToken? cancellationToken,
  }) => _backend.fetchPlace(
    PlaceDetailsRequest(
      placeId: placeId,
      fields: fields,
      languageCode: languageCode,
      regionCode: regionCode,
      sessionToken: sessionToken,
    ),
    cancellationToken: cancellationToken,
  );

  /// Resolves time-zone metadata for geographic coordinates.
  ///
  /// This uses Google Time Zone API, which is separate from Places API and may
  /// be billed separately.
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.fetchTimeZone(request, cancellationToken: cancellationToken);

  /// Resolves time-zone metadata from [place] coordinates.
  ///
  /// Throws [PlacesException] if [place] does not include coordinates.
  Future<PlaceTimeZoneData> fetchTimeZoneForPlace(
    PlaceData place, {
    DateTime? timestamp,
    String? languageCode,
    PlacesCancellationToken? cancellationToken,
  }) => _backend.fetchTimeZone(
    TimeZoneRequest.fromPlace(
      place,
      timestamp: timestamp,
      languageCode: languageCode,
    ),
    cancellationToken: cancellationToken,
  );

  /// Searches for places by free-text query.
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.searchText(request, cancellationToken: cancellationToken);

  /// Searches for places and preserves Text Search pagination metadata.
  ///
  /// Pass [TextSearchPage.nextPageToken] to a subsequent
  /// [TextSearchRequest.pageToken] while keeping the original request filters
  /// unchanged. On web, this operation uses the configured HTTP/proxy path
  /// because Maps JavaScript does not expose REST pagination metadata.
  ///
  /// Because of that, on web this method throws under
  /// [PlacesWebFallbackPolicy.disabled] even though [searchText] succeeds:
  /// there is no JavaScript route to fall back to. Configure a proxy, or use
  /// [searchText] when pagination metadata is not needed.
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.searchTextPage(request, cancellationToken: cancellationToken);

  /// Searches for places near a geographic restriction.
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _backend.searchNearby(request, cancellationToken: cancellationToken);

  /// Releases backend resources held by this client.
  Future<void> close() => _backend.close();
}
