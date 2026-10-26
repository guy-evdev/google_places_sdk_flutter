/// Cross-platform Flutter package for Google Places API (New).
///
/// @docImport 'src/places_client.dart';
/// @docImport 'src/widgets/place_photo_view.dart';
/// @docImport 'src/widgets/places_autocomplete_field.dart';
/// @docImport 'src/widgets/places_autocomplete_overlay.dart';
///
/// This library exports:
/// - request and response models for Places API (New)
/// - a cross-platform [PlacesClient]
/// - paged Text Search with `nextPageToken` and `searchUri` metadata
/// - optional query predictions for autocomplete flows
/// - autocomplete billing-session preservation through place selection
/// - typed errors, request validation, deadlines, and HTTP ownership options
/// - keyless authenticated proxy, mobile identity, and web fallback controls
/// - Place Photos (New) media lookup and a [PlacePhotoView] widget
/// - optional Google Time Zone API integration
/// - inline, dialog, and fullscreen autocomplete widgets
/// - localization strings and controller types for UI integration
///
/// On Android, iOS, macOS, Windows, and Linux, the package uses Places API
/// (New) HTTP requests. On web, including Wasm builds, it uses the Google Maps
/// JavaScript Places library.
///
/// Start with a field:
/// ```dart
/// PlacesAutocompleteField(
///   apiKey: 'YOUR_API_KEY',
///   onSelection: (selection) => debugPrint(selection.place?.formattedAddress),
/// )
/// ```
///
/// Or await a pick from a dialog or full screen with
/// [PlacesAutocompleteOverlay.show]. Use [PlacesClient] directly for place
/// data without a widget.
library;

export 'src/models/place_models.dart';
export 'src/places_client.dart';
export 'src/places_cancellation_token.dart';
export 'src/places_client_options.dart';
export 'src/widgets/places_autocomplete_builders.dart';
export 'src/widgets/places_autocomplete_field.dart';
export 'src/widgets/places_autocomplete_form_field.dart';
export 'src/widgets/place_photo_view.dart';
export 'src/widgets/places_autocomplete_overlay.dart';
export 'src/widgets/places_photo_attribution.dart';
export 'src/widgets/places_strings.dart';
