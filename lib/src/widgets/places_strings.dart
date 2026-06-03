import 'package:flutter/widgets.dart';

/// Localized UI strings used by the autocomplete widgets.
///
/// Provide custom values to localize inline, dialog, and fullscreen widget
/// text without replacing the package UI.
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
  /// Creates a bundle of UI strings for the autocomplete widgets.
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

  /// Title shown at the top of dialog and fullscreen overlays.
  final String overlayTitle;

  /// Accessibility label used for closing overlay routes.
  final String closeLabel;

  /// Tooltip/semantic label for the field clear button.
  final String clearLabel;

  /// Semantic label prefix for place suggestions.
  final String placeSuggestionLabel;

  /// Semantic label prefix for query suggestions.
  final String querySuggestionLabel;
}
