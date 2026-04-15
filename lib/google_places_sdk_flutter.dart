/// Cross-platform Flutter package for Google Places API (New).
///
/// This library exports:
/// - request and response models for Places API (New)
/// - a cross-platform [PlacesClient]
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
export 'src/widgets/places_autocomplete_controller.dart';
export 'src/widgets/places_autocomplete_field.dart';
export 'src/widgets/places_autocomplete_form_field.dart';
export 'src/widgets/places_autocomplete_overlay.dart';
export 'src/widgets/places_strings.dart';
