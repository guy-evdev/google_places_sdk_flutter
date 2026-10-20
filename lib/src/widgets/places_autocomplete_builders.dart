import 'package:flutter/widgets.dart';

import '../models/place_models.dart';
import 'places_strings.dart';

/// Builds the text field of a Places autocomplete widget in place of the
/// default `material_ui` `TextField`.
///
/// See [PlacesFieldData] for what the field must wire up.
typedef PlacesFieldBuilder =
    Widget Function(BuildContext context, PlacesFieldData field);

/// Builds one row of the suggestion list: a [PlaceSuggestion] or, with query
/// predictions on, a [QuerySuggestion].
typedef PlacesSuggestionItemBuilder =
    Widget Function(BuildContext context, PlacesSuggestionItemData item);

/// Builds the whole suggestion area: its container and its loading, empty,
/// error, and results states.
typedef PlacesSuggestionsViewBuilder =
    Widget Function(BuildContext context, PlacesSuggestionsViewData view);

/// What a [PlacesFieldBuilder] receives.
///
/// The field it builds must use [controller] and [focusNode], and call
/// [onChanged] when the user edits the text — the widget searches on that
/// call, not on every change to [controller], so text it sets itself does not
/// start a search. Every type here comes from `package:flutter/widgets.dart`,
/// so the builder can return any text field: Cupertino, a legacy
/// `package:flutter/material.dart` one, or your own.
@immutable
class PlacesFieldData {
  /// Creates the data a [PlacesFieldBuilder] receives.
  const PlacesFieldData({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onTap,
    required this.onClear,
    required this.enabled,
    required this.readOnly,
    required this.autofocus,
    required this.selectionLoading,
    required this.errorText,
    required this.strings,
  });

  /// The text controller the field must use.
  final TextEditingController controller;

  /// The focus node the field must use.
  final FocusNode focusNode;

  /// Call this with the new text whenever the user edits it.
  final ValueChanged<String> onChanged;

  /// Opens the dialog or fullscreen search, in those field modes. `null` in
  /// inline mode and while the field is disabled or loading a selection.
  final VoidCallback? onTap;

  /// Clears the text, the selection, and the search. `null` while there is
  /// nothing to clear, or the field is disabled or loading a selection.
  final VoidCallback? onClear;

  /// Whether the field accepts input.
  final bool enabled;

  /// Whether the text should be read-only: in dialog and fullscreen field
  /// modes, where tapping opens the search instead, and while a selection
  /// loads.
  ///
  /// A field that cannot be made read-only still behaves: edits in those
  /// field modes are ignored, and typing while a selection loads abandons that
  /// selection and starts a new search.
  final bool readOnly;

  /// Whether the field should take focus when it is first built.
  final bool autofocus;

  /// Whether the picked place's details are loading.
  ///
  /// The default field shows a progress bar below itself meanwhile. With a
  /// [PlacesFieldBuilder] the widget draws none, so show your own.
  final bool selectionLoading;

  /// A validation message to show, or `null`.
  ///
  /// `PlacesAutocompleteFormField` puts its validation error here; its
  /// `errorBuilder` styles the default field only.
  final String? errorText;

  /// The widget's strings, such as [PlacesStrings.searchHint] and
  /// [PlacesStrings.clearLabel].
  final PlacesStrings strings;
}

/// What a [PlacesSuggestionItemBuilder] receives.
@immutable
class PlacesSuggestionItemData {
  /// Creates the data a [PlacesSuggestionItemBuilder] receives.
  const PlacesSuggestionItemData({
    required this.suggestion,
    required this.highlighted,
    required this.onSelected,
    required this.strings,
  });

  /// The suggestion to show: a [PlaceSuggestion] or a [QuerySuggestion].
  ///
  /// [AutocompleteSuggestion] is sealed, so a `switch` over it is exhaustive.
  final AutocompleteSuggestion suggestion;

  /// Whether this row is highlighted from the keyboard. Enter selects the
  /// highlighted row, and the first row is highlighted when results arrive.
  final bool highlighted;

  /// Selects this suggestion, exactly as tapping a default row does. Call it
  /// from the row's tap handler.
  final VoidCallback onSelected;

  /// The widget's strings, such as [PlacesStrings.placeSuggestionLabel] and
  /// [PlacesStrings.distanceUnitMeters].
  final PlacesStrings strings;
}

/// The state of the suggestion area, as a [PlacesSuggestionsViewBuilder]
/// receives it.
enum PlacesSuggestionsStatus {
  /// A search is waiting for Google's response, or for its debounce when no
  /// earlier results are on screen. While the debounce runs over earlier
  /// results, the status stays [results].
  loading,

  /// Google returned suggestions; they are in
  /// [PlacesSuggestionsViewData.items].
  results,

  /// The search finished and found nothing.
  empty,

  /// The search failed; see [PlacesSuggestionsViewData.error].
  error,
}

/// What a [PlacesSuggestionsViewBuilder] receives.
///
/// Return [defaultView] for any state you do not want to change.
@immutable
class PlacesSuggestionsViewData {
  /// Creates the data a [PlacesSuggestionsViewBuilder] receives.
  const PlacesSuggestionsViewData({
    required this.status,
    required this.suggestions,
    required this.items,
    required this.error,
    required this.onRetry,
    required this.attribution,
    required this.defaultView,
    required this.strings,
  });

  /// Which state the suggestion area is in.
  final PlacesSuggestionsStatus status;

  /// The suggestions, in Google's order. Empty unless [status] is
  /// [PlacesSuggestionsStatus.results].
  final List<AutocompleteSuggestion> suggestions;

  /// One built row per suggestion — from the
  /// [PlacesSuggestionItemBuilder] when one is set, otherwise the default
  /// rows. Put these in your list rather than building rows here, so
  /// keyboard highlighting keeps the highlighted row in view.
  ///
  /// Default rows are `material_ui` `ListTile`s, each on its own transparent
  /// `Material`.
  final List<Widget> items;

  /// Why the search failed, when [status] is [PlacesSuggestionsStatus.error].
  final PlacesException? error;

  /// Runs the failed search again.
  final VoidCallback onRetry;

  /// Google's "Powered by Google" attribution, or `null` when
  /// `showPoweredByGoogle` is `false`.
  ///
  /// Google requires attribution beside its data when no Google map is shown;
  /// see the
  /// [Places API policies](https://developers.google.com/maps/documentation/places/web-service/policies).
  /// Place it in your view.
  final Widget? attribution;

  /// The package's own view for this state, to return unchanged or to wrap.
  final Widget defaultView;

  /// The widget's strings, such as [PlacesStrings.loadingText] and
  /// [PlacesStrings.retryText].
  final PlacesStrings strings;
}
