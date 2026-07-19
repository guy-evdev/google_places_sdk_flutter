/// Cross-platform Flutter package for Google Places API (New).
///
/// This library exports:
/// - request and response models for Places API (New)
/// - a cross-platform [PlacesClient]
/// - paged Text Search with `nextPageToken` and `searchUri` metadata
/// - optional query predictions for autocomplete flows
/// - autocomplete billing-session preservation through place selection
/// - typed errors, request validation, deadlines, and HTTP ownership options
/// - keyless authenticated proxy, mobile identity, and web fallback controls
/// - Place Photos (New) media lookup
/// - optional Google Time Zone API integration
/// - inline, dialog, and fullscreen autocomplete widgets
/// - localization strings and controller types for UI integration
///
/// On Android, iOS, macOS, Windows, and Linux, the package uses Places API
/// (New) HTTP requests. On web, it uses the Google Maps JavaScript Places
/// library.
///
/// Start with:
/// ```dart
/// final client = PlacesClient(apiKey: 'your-key');
/// ```
///
/// Then create either an inline field or an overlay flow with
/// [PlacesAutocompleteField] or [PlacesAutocompleteOverlay].
library;

export 'src/models/place_models.dart';
export 'src/places_client.dart';
export 'src/places_cancellation_token.dart';
export 'src/places_client_options.dart';
export 'src/widgets/places_autocomplete_controller.dart';
export 'src/widgets/places_autocomplete_field.dart';
export 'src/widgets/places_autocomplete_form_field.dart';
export 'src/widgets/places_autocomplete_overlay.dart';
export 'src/widgets/places_photo_attribution.dart';
export 'src/widgets/places_strings.dart';
