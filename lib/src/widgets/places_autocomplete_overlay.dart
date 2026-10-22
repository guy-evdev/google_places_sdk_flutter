import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_builders.dart';
import 'places_autocomplete_field.dart';
import 'places_design_scope.dart';
import 'places_strings.dart';

/// Presentation mode for [PlacesAutocompleteOverlay].
enum PlacesAutocompleteOverlayMode {
  /// Presents the autocomplete UI inside a dialog route.
  dialog,

  /// Presents the autocomplete UI as a fullscreen route.
  ///
  /// Escape does what the top bar's back button does: the first press closes
  /// the results, the next one calls `Navigator.maybePop` — so it closes the
  /// route [PlacesAutocompleteOverlay.show] pushed, or the page an app mounts
  /// the overlay in. On a first route there is nothing to pop.
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
  ///
  /// It takes the same `TextField` options as the field, passed to its search
  /// field; see [PlacesAutocompleteField.new].
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
    this.includeFutureOpeningBusinesses = false,
    this.fetchPlaceDetailsOnSelection = true,
    this.fetchTimeZoneOnSelection = false,
    this.selectionFields = PlaceFieldPresets.address,
    this.selectionLanguageCode,
    this.selectionRegionCode,
    this.selectionTimeZoneAt,
    this.selectionTimeZoneLanguageCode,
    this.maxSuggestions = 5,
    this.minInputLength = 1,
    this.debounceDuration,
    this.enabled = true,
    this.showPoweredByGoogle = true,
    this.includeQueryPredictions = false,
    this._keyboardType = TextInputType.streetAddress,
    this._textInputAction,
    this._textCapitalization = TextCapitalization.none,
    this._style,
    this._strutStyle,
    this._textAlign = TextAlign.start,
    this._textAlignVertical,
    this._textDirection,
    this._showCursor,
    this._autocorrect,
    this._smartDashesType,
    this._smartQuotesType,
    this._enableSuggestions = true,
    this._maxLength,
    this._maxLengthEnforcement,
    this._onChanged,
    this._onEditingComplete,
    this._onSubmitted,
    this._onAppPrivateCommand,
    this._inputFormatters,
    this._ignorePointers,
    this._cursorWidth = 2.0,
    this._cursorHeight,
    this._cursorRadius,
    this._cursorOpacityAnimates,
    this._cursorColor,
    this._cursorErrorColor,
    this._selectionHeightStyle,
    this._selectionWidthStyle,
    this._keyboardAppearance,
    this._scrollPadding = const EdgeInsets.all(20),
    this._dragStartBehavior = DragStartBehavior.start,
    this._enableInteractiveSelection,
    this._selectAllOnFocus,
    this._selectionControls,
    this._onTap,
    this._onTapAlwaysCalled = false,
    this._onTapOutside,
    this._onTapUpOutside,
    this._mouseCursor,
    this._buildCounter,
    this._scrollController,
    this._scrollPhysics,
    this._autofillHints = const <String>[],
    this._contentInsertionConfiguration,
    this._clipBehavior = Clip.hardEdge,
    this._stylusHandwritingEnabled =
        EditableText.defaultStylusHandwritingEnabled,
    this._enableIMEPersonalizedLearning = true,
    this._enableInlinePrediction,
    this._contextMenuBuilder = PlacesDesignScope.defaultContextMenuBuilder,
    this._spellCheckConfiguration,
    this._magnifierConfiguration,
    this._hintLocales,
    this._groupId = EditableText,
    this._undoController,
    this._statesController,
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
    this.searchOnQuerySelection = false,
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
       ),
       assert(minInputLength >= 1, 'minInputLength must be at least 1.');

  /// Client used to issue autocomplete and optional place-details requests.
  ///
  /// See [PlacesAutocompleteField.client].
  final PlacesClient? client;

  /// API key for an overlay-managed client, closed when the overlay closes.
  ///
  /// See [PlacesAutocompleteField.apiKey].
  final String? apiKey;

  /// The search's controller. The overlay's own parameters and client apply
  /// while it uses it; see [PlacesAutocompleteField.controller].
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
  /// ([LocationRestriction.rectangle]) for autocomplete; a circle there fails
  /// the search with a [PlacesErrorKind.validation] error.
  final LocationRestriction? locationRestriction;

  /// Restricts autocomplete results to Google primary place types.
  final List<String> includedPrimaryTypes;

  /// Restricts autocomplete results to the supplied CLDR region codes.
  final List<String> includedRegionCodes;

  /// Whether pure service-area businesses should be included in autocomplete
  /// results.
  final bool includePureServiceAreaBusinesses;

  /// Whether businesses that have not opened yet should be included in
  /// autocomplete results.
  final bool includeFutureOpeningBusinesses;

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

  /// The fewest characters the user must type before the overlay searches.
  ///
  /// See [PlacesAutocompleteField.minInputLength].
  final int minInputLength;

  /// How long the overlay waits after the user stops typing before it
  /// searches; the [controller]'s when `null`.
  ///
  /// See [PlacesAutocompleteField.debounceDuration].
  final Duration? debounceDuration;

  /// Whether the overlay's field can be interacted with.
  final bool enabled;

  /// Whether the Powered by Google attribution should be shown.
  final bool showPoweredByGoogle;

  /// Whether autocomplete should include query suggestions as well as places.
  ///
  /// On web through the Maps JavaScript API — the default there — only places
  /// are suggested; see [AutocompleteRequest.includeQueryPredictions].
  final bool includeQueryPredictions;

  // The TextField options; see the constructor.
  final TextInputType _keyboardType;
  final TextInputAction? _textInputAction;
  final TextCapitalization _textCapitalization;
  final TextStyle? _style;
  final StrutStyle? _strutStyle;
  final TextAlign _textAlign;
  final TextAlignVertical? _textAlignVertical;
  final TextDirection? _textDirection;
  final bool? _showCursor;
  final bool? _autocorrect;
  final SmartDashesType? _smartDashesType;
  final SmartQuotesType? _smartQuotesType;
  final bool _enableSuggestions;
  final int? _maxLength;
  final MaxLengthEnforcement? _maxLengthEnforcement;
  final ValueChanged<String>? _onChanged;
  final VoidCallback? _onEditingComplete;
  final ValueChanged<String>? _onSubmitted;
  final AppPrivateCommandCallback? _onAppPrivateCommand;
  final List<TextInputFormatter>? _inputFormatters;
  final bool? _ignorePointers;
  final double _cursorWidth;
  final double? _cursorHeight;
  final Radius? _cursorRadius;
  final bool? _cursorOpacityAnimates;
  final Color? _cursorColor;
  final Color? _cursorErrorColor;
  final ui.BoxHeightStyle? _selectionHeightStyle;
  final ui.BoxWidthStyle? _selectionWidthStyle;
  final Brightness? _keyboardAppearance;
  final EdgeInsets _scrollPadding;
  final DragStartBehavior _dragStartBehavior;
  final bool? _enableInteractiveSelection;
  final bool? _selectAllOnFocus;
  final TextSelectionControls? _selectionControls;
  final GestureTapCallback? _onTap;
  final bool _onTapAlwaysCalled;
  final TapRegionCallback? _onTapOutside;
  final TapRegionUpCallback? _onTapUpOutside;
  final MouseCursor? _mouseCursor;
  final InputCounterWidgetBuilder? _buildCounter;
  final ScrollController? _scrollController;
  final ScrollPhysics? _scrollPhysics;
  final Iterable<String>? _autofillHints;
  final ContentInsertionConfiguration? _contentInsertionConfiguration;
  final Clip _clipBehavior;
  final bool _stylusHandwritingEnabled;
  final bool _enableIMEPersonalizedLearning;
  final bool? _enableInlinePrediction;
  final EditableTextContextMenuBuilder? _contextMenuBuilder;
  final SpellCheckConfiguration? _spellCheckConfiguration;
  final TextMagnifierConfiguration? _magnifierConfiguration;
  final List<Locale>? _hintLocales;
  final Object _groupId;
  final UndoHistoryController? _undoController;
  final WidgetStatesController? _statesController;

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

  /// See [PlacesAutocompleteField.searchOnQuerySelection].
  final bool searchOnQuerySelection;

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
  /// It takes the same `TextField` options as the field, passed to the search
  /// field; see [PlacesAutocompleteField.new].
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
    bool includeFutureOpeningBusinesses = false,
    bool fetchPlaceDetailsOnSelection = true,
    bool fetchTimeZoneOnSelection = false,
    Set<PlaceField> selectionFields = PlaceFieldPresets.address,
    String? selectionLanguageCode,
    String? selectionRegionCode,
    DateTime? selectionTimeZoneAt,
    String? selectionTimeZoneLanguageCode,
    int maxSuggestions = 5,
    int minInputLength = 1,
    Duration? debounceDuration,
    bool enabled = true,
    bool showPoweredByGoogle = true,
    bool includeQueryPredictions = false,
    TextInputType keyboardType = TextInputType.streetAddress,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextStyle? style,
    StrutStyle? strutStyle,
    TextAlign textAlign = TextAlign.start,
    TextAlignVertical? textAlignVertical,
    TextDirection? textDirection,
    bool? showCursor,
    bool? autocorrect,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    bool enableSuggestions = true,
    int? maxLength,
    MaxLengthEnforcement? maxLengthEnforcement,
    ValueChanged<String>? onChanged,
    VoidCallback? onEditingComplete,
    ValueChanged<String>? onSubmitted,
    AppPrivateCommandCallback? onAppPrivateCommand,
    List<TextInputFormatter>? inputFormatters,
    bool? ignorePointers,
    double cursorWidth = 2.0,
    double? cursorHeight,
    Radius? cursorRadius,
    bool? cursorOpacityAnimates,
    Color? cursorColor,
    Color? cursorErrorColor,
    ui.BoxHeightStyle? selectionHeightStyle,
    ui.BoxWidthStyle? selectionWidthStyle,
    Brightness? keyboardAppearance,
    EdgeInsets scrollPadding = const EdgeInsets.all(20),
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    bool? selectAllOnFocus,
    TextSelectionControls? selectionControls,
    GestureTapCallback? onTap,
    bool onTapAlwaysCalled = false,
    TapRegionCallback? onTapOutside,
    TapRegionUpCallback? onTapUpOutside,
    MouseCursor? mouseCursor,
    InputCounterWidgetBuilder? buildCounter,
    ScrollController? scrollController,
    ScrollPhysics? scrollPhysics,
    Iterable<String>? autofillHints = const <String>[],
    ContentInsertionConfiguration? contentInsertionConfiguration,
    Clip clipBehavior = Clip.hardEdge,
    bool stylusHandwritingEnabled =
        EditableText.defaultStylusHandwritingEnabled,
    bool enableIMEPersonalizedLearning = true,
    bool? enableInlinePrediction,
    EditableTextContextMenuBuilder? contextMenuBuilder =
        PlacesDesignScope.defaultContextMenuBuilder,
    SpellCheckConfiguration? spellCheckConfiguration,
    TextMagnifierConfiguration? magnifierConfiguration,
    List<Locale>? hintLocales,
    Object groupId = EditableText,
    UndoHistoryController? undoController,
    WidgetStatesController? statesController,
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
    bool searchOnQuerySelection = false,
    VoidCallback? onClearField,
    ValueChanged<Object>? onError,
  }) async {
    assert(
      (client == null) != (apiKey == null),
      'Pass exactly one of client or apiKey.',
    );
    assert(minInputLength >= 1, 'minInputLength must be at least 1.');
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
      includeFutureOpeningBusinesses: includeFutureOpeningBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      minInputLength: minInputLength,
      debounceDuration: debounceDuration,
      enabled: enabled,
      showPoweredByGoogle: showPoweredByGoogle,
      includeQueryPredictions: includeQueryPredictions,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      showCursor: showCursor,
      autocorrect: autocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: enableSuggestions,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onAppPrivateCommand: onAppPrivateCommand,
      inputFormatters: inputFormatters,
      ignorePointers: ignorePointers,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorOpacityAnimates: cursorOpacityAnimates,
      cursorColor: cursorColor,
      cursorErrorColor: cursorErrorColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: enableInteractiveSelection,
      selectAllOnFocus: selectAllOnFocus,
      selectionControls: selectionControls,
      onTap: onTap,
      onTapAlwaysCalled: onTapAlwaysCalled,
      onTapOutside: onTapOutside,
      onTapUpOutside: onTapUpOutside,
      mouseCursor: mouseCursor,
      buildCounter: buildCounter,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      contentInsertionConfiguration: contentInsertionConfiguration,
      clipBehavior: clipBehavior,
      stylusHandwritingEnabled: stylusHandwritingEnabled,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      enableInlinePrediction: enableInlinePrediction,
      contextMenuBuilder: contextMenuBuilder,
      spellCheckConfiguration: spellCheckConfiguration,
      magnifierConfiguration: magnifierConfiguration,
      hintLocales: hintLocales,
      groupId: groupId,
      undoController: undoController,
      statesController: statesController,
      fieldBuilder: fieldBuilder,
      suggestionItemBuilder: suggestionItemBuilder,
      suggestionsViewBuilder: suggestionsViewBuilder,
      suggestionBuilder: suggestionBuilder,
      onSelection: (selection) {
        navigator.pop(selection);
        onSelection?.call(selection);
      },
      onQuerySelection: onQuerySelection,
      searchOnQuerySelection: searchOnQuerySelection,
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
      includeFutureOpeningBusinesses: includeFutureOpeningBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      minInputLength: minInputLength,
      debounceDuration: debounceDuration,
      enabled: enabled,
      showPoweredByGoogle: showPoweredByGoogle,
      includeQueryPredictions: includeQueryPredictions,
      keyboardType: _keyboardType,
      textInputAction: _textInputAction,
      textCapitalization: _textCapitalization,
      style: _style,
      strutStyle: _strutStyle,
      textAlign: _textAlign,
      textAlignVertical: _textAlignVertical,
      textDirection: _textDirection,
      showCursor: _showCursor,
      autocorrect: _autocorrect,
      smartDashesType: _smartDashesType,
      smartQuotesType: _smartQuotesType,
      enableSuggestions: _enableSuggestions,
      maxLength: _maxLength,
      maxLengthEnforcement: _maxLengthEnforcement,
      onChanged: _onChanged,
      onEditingComplete: _onEditingComplete,
      onSubmitted: _onSubmitted,
      onAppPrivateCommand: _onAppPrivateCommand,
      inputFormatters: _inputFormatters,
      ignorePointers: _ignorePointers,
      cursorWidth: _cursorWidth,
      cursorHeight: _cursorHeight,
      cursorRadius: _cursorRadius,
      cursorOpacityAnimates: _cursorOpacityAnimates,
      cursorColor: _cursorColor,
      cursorErrorColor: _cursorErrorColor,
      selectionHeightStyle: _selectionHeightStyle,
      selectionWidthStyle: _selectionWidthStyle,
      keyboardAppearance: _keyboardAppearance,
      scrollPadding: _scrollPadding,
      dragStartBehavior: _dragStartBehavior,
      enableInteractiveSelection: _enableInteractiveSelection,
      selectAllOnFocus: _selectAllOnFocus,
      selectionControls: _selectionControls,
      onTap: _onTap,
      onTapAlwaysCalled: _onTapAlwaysCalled,
      onTapOutside: _onTapOutside,
      onTapUpOutside: _onTapUpOutside,
      mouseCursor: _mouseCursor,
      buildCounter: _buildCounter,
      scrollController: _scrollController,
      scrollPhysics: _scrollPhysics,
      autofillHints: _autofillHints,
      contentInsertionConfiguration: _contentInsertionConfiguration,
      clipBehavior: _clipBehavior,
      stylusHandwritingEnabled: _stylusHandwritingEnabled,
      enableIMEPersonalizedLearning: _enableIMEPersonalizedLearning,
      enableInlinePrediction: _enableInlinePrediction,
      contextMenuBuilder: _contextMenuBuilder,
      spellCheckConfiguration: _spellCheckConfiguration,
      magnifierConfiguration: _magnifierConfiguration,
      hintLocales: _hintLocales,
      groupId: _groupId,
      undoController: _undoController,
      statesController: _statesController,
      fieldBuilder: fieldBuilder,
      suggestionItemBuilder: suggestionItemBuilder,
      suggestionsViewBuilder: suggestionsViewBuilder,
      suggestionBuilder: suggestionBuilder,
      onSelection: onSelection,
      onQuerySelection: onQuerySelection,
      searchOnQuerySelection: searchOnQuerySelection,
      onClearField: onClearField,
      onError: onError,
      autofocus: true,
    );

    final effectiveTitle = title ?? strings.overlayTitle;
    if (mode == PlacesAutocompleteOverlayMode.fullscreen) {
      // The field builds the top bar itself, with the search input in it.
      // Escape does what the bar's back button does; with results open, the
      // field's own Escape closes them first. Inside the Scaffold, whose own
      // (drawer) Dismiss action would stop the lookup.
      return Scaffold(
        body: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) => Navigator.of(context).maybePop(),
            ),
          },
          child: Semantics(
            namesRoute: true,
            explicitChildNodes: true,
            label: effectiveTitle,
            child: field,
          ),
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
