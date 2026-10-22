/// @docImport 'places_autocomplete_field.dart';
library;

import 'package:flutter/widgets.dart';

/// Localized UI strings used by the package's widgets.
///
/// Provide custom values to localize the autocomplete widgets in inline,
/// dialog, and fullscreen modes, and the photo widgets, without replacing the
/// package UI.
///
/// Example:
/// ```dart
/// const PlacesStrings(
///   searchHint: 'חיפוש מקום',
///   noResultsText: 'לא נמצאו תוצאות',
/// )
/// ```
@immutable
class PlacesStrings {
  /// Creates a bundle of UI strings for the package's widgets.
  const PlacesStrings({
    this.searchHint = 'Search places',
    this.loadingText = 'Loading places…',
    this.noResultsText = 'No matching places found.',
    this.errorText = 'Unable to load places.',
    this.retryText = 'Retry',
    this.poweredByGoogleLabel = 'Powered by Google',
    this.overlayTitle = 'Search places',
    this.closeLabel = 'Close',
    this.clearLabel = 'Clear search',
    this.placeSuggestionLabel = 'Place suggestion',
    this.querySuggestionLabel = 'Query suggestion',
    this.distanceUnitMeters = 'm',
    this.photoAttributionPrefix = 'Photo by',
    this.viewOnGoogleMapsText = 'View on Google Maps',
  });

  /// Placeholder text shown in the search field.
  final String searchHint;

  /// Text shown while suggestions are loading.
  final String loadingText;

  /// Text shown when no matching suggestions are returned.
  final String noResultsText;

  /// Generic error text shown when a request fails.
  final String errorText;

  /// Label used for retry actions in error states.
  final String retryText;

  /// Accessibility label used for the Google attribution image.
  final String poweredByGoogleLabel;

  /// Title of the dialog and fullscreen search.
  ///
  /// The dialog shows it above the field. The fullscreen search puts the
  /// field in the top bar instead, so screen readers announce this as the
  /// screen's name.
  final String overlayTitle;

  /// Label for the control that closes the dialog or fullscreen search: the
  /// close button in the dialog, the back button in the fullscreen top bar.
  final String closeLabel;

  /// Tooltip/semantic label for the field clear button.
  final String clearLabel;

  /// Semantic label prefix for place suggestions.
  final String placeSuggestionLabel;

  /// Semantic label prefix for query suggestions.
  final String querySuggestionLabel;

  /// Unit suffix appended to the suggestion distance, such as `'m'`.
  ///
  /// Suggestions only carry a distance when
  /// [PlacesAutocompleteField.origin] is set. The value is rendered in meters
  /// exactly as Google returns it; conversion to kilometers or miles and
  /// locale-aware number formatting are planned for `0.8.0`.
  final String distanceUnitMeters;

  /// Text placed before a photo's author names, as in "Photo by Ana Lima", by
  /// `PlacePhotoView` and `PlacesPhotoAttribution`.
  final String photoAttributionPrefix;

  /// Text of the link that opens a photo on Google Maps, drawn after the
  /// author names by `PlacePhotoView` and `PlacesPhotoAttribution`.
  final String viewOnGoogleMapsText;
}
