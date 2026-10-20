import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_builders.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_field.dart';
import 'places_design_scope.dart';
import 'places_strings.dart';

/// Presentation mode for [PlacesAutocompleteOverlay].
enum PlacesAutocompleteOverlayMode {
  /// Presents the autocomplete UI inside a dialog route.
  dialog,

  /// Presents the autocomplete UI as a fullscreen route.
  fullscreen,
}

/// Standalone autocomplete search surface shown as a dialog or fullscreen route.
///
/// This wraps [PlacesAutocompleteField] and is useful when the search UI should
/// live in a dedicated route instead of inline. The field stays in place and
/// only the results scroll.
///
/// Most apps call [show]. To mount the overlay yourself, give it a bounded
/// height, as a route or a dialog does.
class PlacesAutocompleteOverlay extends StatelessWidget {
  /// Creates a standalone autocomplete overlay.
  ///
  /// Exactly one of [client] and [apiKey] must be supplied.
  const PlacesAutocompleteOverlay({
    super.key,
    this.client,
    this.apiKey,
    required this.controller,
    required this.mode,
    this.title,
    this.decoration,
    this.strings = const PlacesStrings(),
    this.languageCode,
    this.regionCode,
    this.origin,
    this.locationBias,
    this.locationRestriction,
    this.includedPrimaryTypes = const <String>[],
    this.includedRegionCodes = const <String>[],
    this.includePureServiceAreaBusinesses = false,
    this.fetchPlaceDetailsOnSelection = true,
    this.fetchTimeZoneOnSelection = false,
    this.selectionFields = PlaceFieldPresets.address,
    this.selectionLanguageCode,
    this.selectionRegionCode,
    this.selectionTimeZoneAt,
    this.selectionTimeZoneLanguageCode,
    this.maxSuggestions = 5,
    this.enabled = true,
    this.showPoweredByGoogle = true,
    this.includeQueryPredictions = false,
    this.fieldBuilder,
    this.suggestionItemBuilder,
    this.suggestionsViewBuilder,
    @Deprecated(
      'Use suggestionItemBuilder, which builds the whole row. '
      'suggestionBuilder is deprecated in 0.7.0 and will be removed in 1.0.0.',
    )
    this.suggestionBuilder,
    this.onSelection,
    this.onQuerySelection,
    this.onClearField,
    this.onError,
  }) : assert(
         (client == null) != (apiKey == null),
         'Pass exactly one of client or apiKey.',
       ),
       assert(
         suggestionBuilder == null || suggestionItemBuilder == null,
         'Pass suggestionItemBuilder or the deprecated suggestionBuilder, '
         'not both.',
       );

  /// Client used to issue autocomplete and optional place-details requests.
  ///
  /// See [PlacesAutocompleteField.client].
  final PlacesClient? client;

  /// API key for an overlay-managed client, closed when the overlay closes.
  ///
  /// See [PlacesAutocompleteField.apiKey].
  final String? apiKey;

  /// Controller used by the overlay field.
  final PlacesAutocompleteController controller;

  /// Whether the overlay should be presented as a dialog or fullscreen route.
  final PlacesAutocompleteOverlayMode mode;

  /// Title for the search surface. Defaults to [PlacesStrings.overlayTitle].
  ///
  /// Dialog mode shows it above the field. Fullscreen mode puts the field in
  /// the top bar, as platform search screens do, so the title is not drawn
  /// there; screen readers announce it as the screen's name instead.
  final String? title;

  /// Optional base decoration for the overlay's text field.
  ///
  /// In fullscreen mode the field sits in the top bar and has no border unless
  /// this decoration sets one. Not used with a [fieldBuilder].
  final InputDecoration? decoration;

  /// The overlay's own text: the title, the hint, the messages, and the
  /// screen-reader labels. Every default is English.
  final PlacesStrings strings;

  /// Preferred BCP-47 language code for autocomplete results.
  final String? languageCode;

  /// Preferred CLDR region code for autocomplete results.
  final String? regionCode;

  /// Origin used by Google to compute the distance to each suggestion.
  ///
  /// See [PlacesAutocompleteField.origin].
  final PlaceCoordinates? origin;

  /// Soft geographic preference applied to autocomplete results.
  final LocationBias? locationBias;

  /// Hard geographic restriction applied to autocomplete results.
  ///
  /// A circle or a rectangle, except through the Maps JavaScript backend — the
  /// web default — which accepts only a rectangle
  /// ([LocationRestriction.rectangle]) for autocomplete.
  final LocationRestriction? locationRestriction;

  /// Restricts autocomplete results to Google primary place types.
  final List<String> includedPrimaryTypes;

  /// Restricts autocomplete results to the supplied CLDR region codes.
  final List<String> includedRegionCodes;
  final bool includePureServiceAreaBusinesses;

  /// Whether the selected suggestion should be resolved into [PlaceData]
  /// before [onSelection] fires and before [show] completes.
  final bool fetchPlaceDetailsOnSelection;

  /// Whether the selected suggestion should also resolve time-zone metadata.
  ///
  /// This implies place-details resolution because time-zone lookups require
  /// place coordinates.
  final bool fetchTimeZoneOnSelection;

  /// Field set used when [fetchPlaceDetailsOnSelection] is enabled.
  final Set<PlaceField> selectionFields;

  /// Preferred BCP-47 language code for the follow-up place-details request.
  final String? selectionLanguageCode;

  /// Preferred CLDR region code for the follow-up place-details request.
  final String? selectionRegionCode;

  /// Timestamp to use for the optional time-zone lookup.
  final DateTime? selectionTimeZoneAt;

  /// Optional BCP-47 language code for localized time-zone names.
  final String? selectionTimeZoneLanguageCode;

  /// Maximum number of autocomplete suggestions to display.
  ///
  /// Google Autocomplete (New) returns at most five predictions, so values
  /// above `5` are clamped to the upstream response limit.
  final int maxSuggestions;

  /// Whether the overlay's field can be interacted with.
  final bool enabled;

  /// Whether the Powered by Google attribution should be shown.
  final bool showPoweredByGoogle;

  /// Whether autocomplete should include query suggestions as well as places.
  final bool includeQueryPredictions;

  /// Builds the search field. See [PlacesAutocompleteField.fieldBuilder].
  final PlacesFieldBuilder? fieldBuilder;

  /// Builds each suggestion row. See
  /// [PlacesAutocompleteField.suggestionItemBuilder].
  final PlacesSuggestionItemBuilder? suggestionItemBuilder;

  /// Builds the suggestion area. See
  /// [PlacesAutocompleteField.suggestionsViewBuilder].
  final PlacesSuggestionsViewBuilder? suggestionsViewBuilder;

  /// Builds the title of a place suggestion's default row.
  ///
  /// Deprecated: [suggestionItemBuilder] builds the whole row.
  @Deprecated(
    'Use suggestionItemBuilder, which builds the whole row. '
    'suggestionBuilder is deprecated in 0.7.0 and will be removed in 1.0.0.',
  )
  final Widget Function(BuildContext context, PlaceSuggestion suggestion)?
  suggestionBuilder;

  /// Called when the user selects a suggestion, optionally with resolved place
  /// details.
  final ValueChanged<PlaceSelection>? onSelection;

  /// Called when the user selects a query suggestion.
  final ValueChanged<QuerySuggestion>? onQuerySelection;

  /// Called after the overlay field's clear action is pressed.
  final VoidCallback? onClearField;

  /// Called when autocomplete, place-details, or time-zone loading fails.
  final ValueChanged<Object>? onError;

  /// Opens a Places autocomplete overlay and returns the user’s selection.
  ///
  /// ```dart
  /// final selection = await PlacesAutocompleteOverlay.show(
  ///   context,
  ///   apiKey: 'YOUR_API_KEY',
  /// );
  /// ```
  ///
  /// Pass exactly one of [client] and [apiKey]. Given a key, the overlay
  /// creates its own client and closes it once the overlay has closed.
  ///
  /// If [controller] is omitted, the overlay creates and disposes an internal
  /// controller. Use [initialText] to seed the overlay input when launching
  /// from an existing field value.
  ///
  /// This is useful for field-launcher flows where the actual editing
  /// experience should happen in a dialog or fullscreen route.
  static Future<PlaceSelection?> show(
    BuildContext context, {
    PlacesClient? client,
    String? apiKey,
    PlacesAutocompleteController? controller,
    String initialText = '',
    PlacesAutocompleteOverlayMode mode = PlacesAutocompleteOverlayMode.dialog,
    bool useRootNavigator = true,
    InputDecoration? decoration,
    PlacesStrings strings = const PlacesStrings(),
    String? title,
    String? languageCode,
    String? regionCode,
    PlaceCoordinates? origin,
    LocationBias? locationBias,
    LocationRestriction? locationRestriction,
    List<String> includedPrimaryTypes = const <String>[],
    List<String> includedRegionCodes = const <String>[],
    bool includePureServiceAreaBusinesses = false,
    bool fetchPlaceDetailsOnSelection = true,
    bool fetchTimeZoneOnSelection = false,
    Set<PlaceField> selectionFields = PlaceFieldPresets.address,
    String? selectionLanguageCode,
    String? selectionRegionCode,
    DateTime? selectionTimeZoneAt,
    String? selectionTimeZoneLanguageCode,
    int maxSuggestions = 5,
    bool enabled = true,
    bool showPoweredByGoogle = true,
    bool includeQueryPredictions = false,
    PlacesFieldBuilder? fieldBuilder,
    PlacesSuggestionItemBuilder? suggestionItemBuilder,
    PlacesSuggestionsViewBuilder? suggestionsViewBuilder,
    @Deprecated(
      'Use suggestionItemBuilder, which builds the whole row. '
      'suggestionBuilder is deprecated in 0.7.0 and will be removed in 1.0.0.',
    )
    Widget Function(BuildContext context, PlaceSuggestion suggestion)?
    suggestionBuilder,
    ValueChanged<PlaceSelection>? onSelection,
    ValueChanged<QuerySuggestion>? onQuerySelection,
    VoidCallback? onClearField,
    ValueChanged<Object>? onError,
  }) async {
    assert(
      (client == null) != (apiKey == null),
      'Pass exactly one of client or apiKey.',
    );
    final ownedController = controller == null
        ? PlacesAutocompleteController(initialText: initialText)
        : null;
    final effectiveController = controller ?? ownedController!;
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    // Themes set around the caller — a Theme, a ListTileTheme — reach the
    // route, as showDialog does.
    final themes = InheritedTheme.capture(from: context, to: navigator.context);
    final child = PlacesAutocompleteOverlay(
      client: client,
      apiKey: apiKey,
      controller: effectiveController,
      mode: mode,
      title: title,
      decoration: decoration,
      strings: strings,
      languageCode: languageCode,
      regionCode: regionCode,
      origin: origin,
      locationBias: locationBias,
      locationRestriction: locationRestriction,
      includedPrimaryTypes: includedPrimaryTypes,
      includedRegionCodes: includedRegionCodes,
      includePureServiceAreaBusinesses: includePureServiceAreaBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      enabled: enabled,
      showPoweredByGoogle: showPoweredByGoogle,
      includeQueryPredictions: includeQueryPredictions,
      fieldBuilder: fieldBuilder,
      suggestionItemBuilder: suggestionItemBuilder,
      suggestionsViewBuilder: suggestionsViewBuilder,
      suggestionBuilder: suggestionBuilder,
      onSelection: (selection) {
        navigator.pop(selection);
        onSelection?.call(selection);
      },
      onQuerySelection: onQuerySelection,
      onClearField: onClearField,
      onError: onError,
    );

    try {
      if (mode == PlacesAutocompleteOverlayMode.fullscreen) {
        return await navigator.push<PlaceSelection>(
          MaterialPageRoute<PlaceSelection>(
            // The overlay applies PlacesDesignScope itself. A regular page,
            // so the back button in its bar matches the platform's own back
            // navigation, including the iOS edge swipe.
            builder: (_) => themes.wrap(child),
          ),
        );
      }

      // Not showDialog: it asserts material_ui MaterialLocalizations on the
      // caller's context, which an app still on package:flutter/material.dart
      // does not have. Pushing the route showDialog builds avoids that, and
      // the route's content gets PlacesDesignScope like every other root.
      return await navigator.push<PlaceSelection>(
        DialogRoute<PlaceSelection>(
          context: context,
          themes: themes,
          barrierColor: DialogTheme.of(context).barrierColor ?? Colors.black54,
          barrierLabel:
              Localizations.of<MaterialLocalizations>(
                context,
                MaterialLocalizations,
              )?.modalBarrierDismissLabel ??
              strings.closeLabel,
          traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
          builder: (dialogContext) => PlacesDesignScope(
            child: Dialog(
              // Clipped so the results scroll under the rounded corners.
              clipBehavior: Clip.antiAlias,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 560,
                  maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    } finally {
      if (ownedController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ownedController.dispose();
        });
      }
    }
  }

  // The title row, the field, one result row, and the attribution.
  static const double _minPinnedDialogHeight = 240;

  @override
  Widget build(BuildContext context) {
    // Public, so it can be mounted outside show(), including in an app still
    // on package:flutter/material.dart.
    return PlacesDesignScope(child: Builder(builder: _buildOverlay));
  }

  Widget _buildOverlay(BuildContext context) {
    // The field owns the client made from apiKey, so it is closed only after
    // the field has cancelled its in-flight requests.
    final field = PlacesAutocompleteField(
      client: client,
      apiKey: apiKey,
      controller: controller,
      decoration: decoration,
      strings: strings,
      languageCode: languageCode,
      regionCode: regionCode,
      origin: origin,
      locationBias: locationBias,
      locationRestriction: locationRestriction,
      includedPrimaryTypes: includedPrimaryTypes,
      includedRegionCodes: includedRegionCodes,
      includePureServiceAreaBusinesses: includePureServiceAreaBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      enabled: enabled,
      showPoweredByGoogle: showPoweredByGoogle,
      includeQueryPredictions: includeQueryPredictions,
      fieldBuilder: fieldBuilder,
      suggestionItemBuilder: suggestionItemBuilder,
      suggestionsViewBuilder: suggestionsViewBuilder,
      suggestionBuilder: suggestionBuilder,
      onSelection: onSelection,
      onQuerySelection: onQuerySelection,
      onClearField: onClearField,
      onError: onError,
      autofocus: true,
    );

    final effectiveTitle = title ?? strings.overlayTitle;
    if (mode == PlacesAutocompleteOverlayMode.fullscreen) {
      // The field builds the top bar itself, with the search input in it.
      return Scaffold(
        body: Semantics(
          namesRoute: true,
          explicitChildNodes: true,
          label: effectiveTitle,
          child: field,
        ),
      );
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  effectiveTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: strings.closeLabel,
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Flexible(child: field),
      ],
    );
    // The title and field stay put while the results scroll — given room for
    // them above a row of results. A shorter dialog, as on a phone in
    // landscape with the keyboard up, scrolls as a whole instead of
    // overflowing. One tree shape either way, so the field is never rebuilt
    // (and never loses focus) as the keyboard comes and goes.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: math.max(constraints.maxHeight, _minPinnedDialogHeight),
          ),
          child: content,
        ),
      ),
    );
  }
}
