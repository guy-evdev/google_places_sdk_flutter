/// @docImport '../places_client_options.dart';
library;

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import '../places_cancellation_token.dart';
import 'places_autocomplete_builders.dart';
import 'places_autocomplete_overlay.dart';
import 'places_design_scope.dart';
import 'places_strings.dart';

part 'places_autocomplete_controller.dart';

/// Controls how [PlacesAutocompleteField] behaves.
///
/// - [inline]: a regular editable text field with inline suggestions.
/// - [dialog]: a read-only launcher field that opens dialog search UI.
/// - [fullscreen]: a read-only launcher field that opens fullscreen search UI.
enum PlacesAutocompleteFieldMode {
  /// Shows an editable text field with inline suggestions below it.
  inline,

  /// Shows a read-only launcher field that opens dialog search UI.
  dialog,

  /// Shows a read-only launcher field that opens fullscreen search UI.
  fullscreen,
}

/// A cross-platform Google Places autocomplete field built on Places API (New).
///
/// This widget supports inline search, dialog launch, and fullscreen launch
/// modes through [fieldMode].
///
/// Pass either [apiKey], and the field manages its own [PlacesClient], or a
/// [client] you own.
///
/// Example:
/// ```dart
/// PlacesAutocompleteField(
///   apiKey: 'YOUR_API_KEY',
///   languageCode: 'en',
///   regionCode: 'us',
///   includedPrimaryTypes: const <String>['restaurant'],
///   onSelection: (selection) {
///     debugPrint('${selection.displayText} ${selection.place?.location}');
///   },
/// )
/// ```
class PlacesAutocompleteField extends StatefulWidget {
  /// Creates a Places autocomplete field or launcher.
  ///
  /// Exactly one of [client] and [apiKey] must be supplied.
  ///
  /// ## `TextField` options
  ///
  /// It also takes [TextField]'s own options, under their names and with
  /// their defaults, and passes them to its text field — in dialog and
  /// fullscreen modes to the search field too. That is every option except
  /// the ones the widget provides itself ([controller] — which also holds the
  /// `focusNode` — [decoration], [enabled], [autofocus]) and the ones a
  /// one-line search field cannot
  /// honour: `readOnly`, `canRequestFocus`, `obscureText`,
  /// `obscuringCharacter`, `maxLines`, `minLines`, `expands`,
  /// `restorationId`, and the deprecated `toolbarOptions` and
  /// `scribbleEnabled`. They configure the package's field only; a
  /// [fieldBuilder] sets them on its own. Where they differ from `TextField`:
  ///
  /// * `keyboardType` defaults to [TextInputType.streetAddress]: a keyboard
  ///   suited to addresses on Android, and a hint to capitalize words on
  ///   Linux. iOS, the web, macOS, and Windows show the usual text keyboard.
  /// * `onChanged`, `onTap`, `onTapOutside`, and `onTapUpOutside` are called
  ///   as well as the field's own handling, not instead of it: typing still
  ///   searches, a launcher tap still opens the search, and a tap outside
  ///   still does what `TextField` does by default. To keep focus on a tap
  ///   outside, override [EditableTextTapOutsideIntent] with an [Actions]
  ///   widget above the field.
  /// * `contextMenuBuilder`'s menu also works in apps still on
  ///   `package:flutter/material.dart`; `null` turns the menu off, as for
  ///   `TextField`. Flutter's default menu is
  ///   [AdaptiveTextSelectionToolbar.editableText].
  /// * `scrollController`, `undoController`, and `statesController` attach to
  ///   the field the user types in. In dialog and fullscreen modes that is
  ///   the search field, never the read-only launcher.
  /// * `groupId` also covers the suggestions, so tapping one does not count
  ///   as a tap outside the field.
  ///
  /// As in any `TextField`, the keyboard's action button gives up focus by
  /// default, which closes the suggestions; pass `onEditingComplete` to keep
  /// them open. `autofillHints` of `null` turns autofill off for the field.
  const PlacesAutocompleteField({
    super.key,
    this.client,
    this.apiKey,
    this.controller,
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
    this.fieldMode = PlacesAutocompleteFieldMode.inline,
    this.onSelection,
    this.onClearField,
    this.onError,
    this.maxSuggestions = 5,
    this.minInputLength = 1,
    this.debounceDuration,
    this.enabled = true,
    this.autofocus = false,
    this.unfocusOnSelection = true,
    this.suggestionsViewOpenDirection = OptionsViewOpenDirection.mostSpace,
    this.showPoweredByGoogle = true,
    this.includeQueryPredictions = false,
    this.onQuerySelection,
    this.searchOnQuerySelection = false,
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

  /// Client used for autocomplete, place-details, and optional time-zone calls.
  ///
  /// Pass a client instead of [apiKey] to share one client across screens, or
  /// to use a keyless proxy with [PlacesClient.proxy] so no key ships in the
  /// app. The caller owns it: the field never closes a client it was given.
  final PlacesClient? client;

  /// Google Maps Platform API key, for when the field should manage its own
  /// client.
  ///
  /// The field creates a [PlacesClient] from this key, closes it when the
  /// field is disposed, and replaces it if the key changes. Use [client]
  /// instead to share a client or to keep keys off the device.
  ///
  /// That client is `PlacesClient(apiKey: apiKey)` with default
  /// [PlacesClientOptions]: on web it uses the Maps JavaScript backend with the
  /// default [PlacesWebOptions]; elsewhere it calls REST and sends no
  /// application identity. A key restricted to your Android or iOS app needs
  /// [PlacesClientOptions.applicationIdentity]: pass a [client] built with it.
  /// In dialog and fullscreen modes the opened overlay makes its own client
  /// from the same key.
  final String? apiKey;

  /// A controller to read or drive the search from outside the field: its
  /// text, focus, session, suggestions, and selection.
  ///
  /// When omitted, the field creates its own. While the field uses one, the
  /// field's own parameters and client apply, not the controller's `options`
  /// and client. In dialog and fullscreen modes it holds the launcher's text
  /// and selection; the search opens with a controller of its own.
  final PlacesAutocompleteController? controller;

  /// Optional base decoration for the text field UI.
  ///
  /// Used by the default field only. A [fieldBuilder] builds its own field
  /// and receives this decoration's `errorText` as [PlacesFieldData.errorText].
  final InputDecoration? decoration;

  /// The widget's own text: the hint, the loading, empty, and error messages,
  /// and the screen-reader labels. Every default is English.
  final PlacesStrings strings;

  /// Preferred BCP-47 language code for results, such as `'en'` or `'he'`.
  final String? languageCode;

  /// Preferred CLDR region code for results, such as `'us'` or `'il'`.
  final String? regionCode;

  /// Origin used by Google to compute the distance to each suggestion.
  ///
  /// Suggestions only carry [PlaceSuggestion.distanceMeters] when this is set,
  /// so the field renders a distance next to each place suggestion only while
  /// an origin is supplied. The distance unit comes from
  /// [PlacesStrings.distanceUnitMeters].
  ///
  /// This does not bias or restrict which places are returned. Use
  /// [locationBias] or [locationRestriction] for that.
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

  /// Restricts autocomplete results to places whose primary type matches one
  /// of these Google Places primary-type values.
  ///
  /// Examples:
  /// ```dart
  /// includedPrimaryTypes: const <String>['restaurant']
  /// includedPrimaryTypes: const <String>['cafe', 'bakery']
  /// includedPrimaryTypes: const <String>['(cities)']
  /// ```
  ///
  /// See Google’s supported type documentation:
  /// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete#includedPrimaryTypes
  final List<String> includedPrimaryTypes;

  /// Restricts autocomplete results to the supplied CLDR region codes.
  final List<String> includedRegionCodes;

  /// Whether pure service-area businesses should be included in autocomplete
  /// results.
  final bool includePureServiceAreaBusinesses;

  /// Whether businesses that have not opened yet should be included in
  /// autocomplete results.
  final bool includeFutureOpeningBusinesses;

  /// Whether a selected suggestion should be resolved into [PlaceData] before
  /// [onSelection] is called.
  ///
  /// On by default, so a selection carries coordinates and a parsed address.
  /// The details request ends the user's autocomplete session, which is how
  /// Google prices sessions. With the default [PlaceFieldPresets.address] it is
  /// billed as Place Details Essentials, along with the session's first 12
  /// autocomplete requests. Set this to `false` to receive only the suggestion
  /// and skip that request.
  final bool fetchPlaceDetailsOnSelection;

  /// Whether a selected suggestion should also resolve time-zone metadata.
  ///
  /// This implicitly resolves place details first because time-zone lookup
  /// requires geographic coordinates.
  final bool fetchTimeZoneOnSelection;

  /// The fields to request when [fetchPlaceDetailsOnSelection] is enabled.
  ///
  /// Defaults to [PlaceFieldPresets.address], all Essentials. Because this
  /// request ends the autocomplete session, one Pro or Enterprise field —
  /// [PlaceFieldPresets.recommended] has several — bills it at Place Details
  /// Enterprise + Atmosphere instead, and makes the session's autocomplete
  /// requests free. See Google's
  /// [session pricing](https://developers.google.com/maps/documentation/places/web-service/session-pricing).
  ///
  /// If [fetchTimeZoneOnSelection] is enabled, the widget will automatically
  /// ensure that [PlaceField.location] is included even if it is not present
  /// here.
  final Set<PlaceField> selectionFields;

  /// Preferred BCP-47 language code for the follow-up place-details request.
  final String? selectionLanguageCode;

  /// Preferred CLDR region code for the follow-up place-details request.
  final String? selectionRegionCode;

  /// Timestamp to use for the time-zone lookup.
  final DateTime? selectionTimeZoneAt;

  /// Optional BCP-47 language code for localized time-zone names.
  ///
  /// If omitted, the widget falls back to [selectionLanguageCode] and then
  /// [languageCode].
  final String? selectionTimeZoneLanguageCode;

  /// How the field should behave: inline search, dialog launcher, or
  /// fullscreen launcher.
  final PlacesAutocompleteFieldMode fieldMode;

  /// Called when the user selects a suggestion or resolved place.
  final ValueChanged<PlaceSelection>? onSelection;

  /// Called when the user presses the clear button — in the dialog or
  /// fullscreen search too, which clears this field as well — or types over
  /// a picked place.
  ///
  /// With [onSelection], it keeps other fields filled from the pick in step;
  /// see the address-form recipe in `doc/recipes.md`.
  final VoidCallback? onClearField;

  /// Called when autocomplete, place-details, or time-zone loading fails.
  final ValueChanged<Object>? onError;

  /// Maximum number of autocomplete suggestions to display.
  ///
  /// Google Autocomplete (New) returns at most five predictions, so values
  /// above `5` are clamped to the upstream response limit.
  ///
  /// Official reference:
  /// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
  final int maxSuggestions;

  /// The fewest characters the user must type before the field searches.
  ///
  /// Shorter input sends no request and shows no suggestions. Every search is
  /// a billed autocomplete request, so a higher minimum sends fewer of them.
  /// Characters are counted as the user sees them, after trimming spaces.
  /// Defaults to `1`, the least it can be. Some place names are short: `北京`
  /// is two characters.
  final int minInputLength;

  /// How long the field waits after the user stops typing before it searches.
  ///
  /// Every search is a billed autocomplete request, so a longer wait sends
  /// fewer of them. When `null`, the [controller]'s
  /// [PlacesAutocompleteController.debounceDuration] applies: 300 ms unless
  /// set there.
  final Duration? debounceDuration;

  /// Whether the field can be interacted with.
  final bool enabled;

  /// Whether the field should request focus automatically.
  final bool autofocus;

  /// Whether the field gives up focus when the user picks a place, which on a
  /// phone also hides the keyboard.
  ///
  /// Set it to `false` to keep focus in the field, for example so a keyboard
  /// user stays where they were. The field then stays editable while the
  /// place's details load, and typing abandons that pick. Inline mode only:
  /// the dialog and fullscreen search close when a place is picked.
  final bool unfocusOnSelection;

  /// Which side of the field the suggestions open on.
  ///
  /// [OptionsViewOpenDirection.mostSpace], the default, picks the side with
  /// more room between the field and the screen edge or the keyboard;
  /// [OptionsViewOpenDirection.down] and [OptionsViewOpenDirection.up] always
  /// use that side — with less than a row of room there, the suggestions
  /// overlap the field. Inline mode only: in the dialog and fullscreen search
  /// the suggestions always sit below the field.
  final OptionsViewOpenDirection suggestionsViewOpenDirection;

  /// Whether the Powered by Google attribution should be shown.
  final bool showPoweredByGoogle;

  /// Whether autocomplete should include query suggestions as well as places.
  ///
  /// On web through the Maps JavaScript API — the default there — only places
  /// are suggested; see [AutocompleteRequest.includeQueryPredictions].
  final bool includeQueryPredictions;

  /// Called when the user selects a query suggestion.
  final ValueChanged<QuerySuggestion>? onQuerySelection;

  /// Whether picking a query suggestion searches for its text at once.
  ///
  /// A query pick puts the suggested text in the field, closes the
  /// suggestions, ends the billing session, and calls [onQuerySelection].
  /// When `true`, it then searches for that text in a new session, so the
  /// user can pick a place from the results — unless the text is shorter
  /// than [minInputLength]. Works in every field mode; in the dialog and
  /// fullscreen search the results show there. Defaults to `false`.
  final bool searchOnQuerySelection;

  /// Builds the text field in place of the default `material_ui` one.
  ///
  /// The builder receives the controller, focus node, and callbacks the field
  /// must use; see [PlacesFieldData]. It builds the launcher field in dialog
  /// and fullscreen field modes, and the search field inside the dialog or
  /// fullscreen search. [decoration] is used only for its `errorText`, passed
  /// on as [PlacesFieldData.errorText] — so in `PlacesAutocompleteFormField`
  /// the validation message reaches your field, and that form field's
  /// `errorBuilder` is not used. The progress bar the default field shows
  /// while a selection loads is not drawn: render
  /// [PlacesFieldData.selectionLoading] yourself. The `TextField` options
  /// the constructor takes configure the default field only; set them on
  /// your own.
  ///
  /// Every type it receives comes from `package:flutter/widgets.dart`, so an
  /// app still on `package:flutter/material.dart` can return its own
  /// `TextField` and get its own theme. Inside the dialog and fullscreen
  /// search such a field needs a `Material` from that library above it.
  final PlacesFieldBuilder? fieldBuilder;

  /// Builds each suggestion row in place of the default `ListTile`.
  ///
  /// It receives both kinds of suggestion — [PlaceSuggestion] and, with
  /// [includeQueryPredictions], [QuerySuggestion] — with whether the row is
  /// highlighted from the keyboard and a callback that selects it. See
  /// [PlacesSuggestionItemData]. The row it returns is not wrapped in
  /// `Semantics`; label it yourself.
  ///
  /// To restyle the default rows without building them, set
  /// `ThemeData.listTileTheme` on a `Theme` around the field instead. A
  /// `ListTileTheme` widget works inline only: Flutter does not carry its text
  /// styles into the dialog or fullscreen search.
  final PlacesSuggestionItemBuilder? suggestionItemBuilder;

  /// Builds the suggestion area in place of the default card or list.
  ///
  /// It receives the area's status — loading, results, empty, or error — the
  /// built rows, the typed [PlacesException] when a search fails, a retry
  /// callback, Google's attribution, and the package's own view for the
  /// current state; see [PlacesSuggestionsViewData]. Return
  /// [PlacesSuggestionsViewData.defaultView] for the states you keep.
  ///
  /// Inline, the area floats over the page beside the field, with the
  /// field's width and the height left between it and the screen edge or the
  /// keyboard. In the dialog and fullscreen search it sits below the field.
  final PlacesSuggestionsViewBuilder? suggestionsViewBuilder;

  /// Builds the title of a place suggestion's default row.
  ///
  /// Deprecated: [suggestionItemBuilder] builds the whole row, for place and
  /// query suggestions alike.
  @Deprecated(
    'Use suggestionItemBuilder, which builds the whole row. '
    'suggestionBuilder is deprecated in 0.7.0 and will be removed in 1.0.0.',
  )
  final Widget Function(BuildContext context, PlaceSuggestion suggestion)?
  suggestionBuilder;

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

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField>
    with WidgetsBindingObserver {
  PlacesAutocompleteController? _ownedController;
  PlacesClient? _ownedClient;
  bool _suggestionPointerDown = false;
  bool _hasText = false;
  // Inline suggestions float in the nearest Overlay. Always shown: the overlay
  // child is empty while the search UI is closed, so visibility follows the
  // controller without a second flag to keep in sync. The portal must stay
  // mounted in every mode: one that unmounts loses its shown state.
  final OverlayPortalController _suggestionsPortal = OverlayPortalController()
    ..show();

  PlacesClient get _client => widget.client ?? _ownedClient!;

  late PlacesAutocompleteOptions _options = _optionsOf(widget);

  void _createOwnedClient() {
    _ownedClient = widget.client == null
        ? PlacesClient(apiKey: widget.apiKey!)
        : null;
  }

  PlacesAutocompleteController get _controller =>
      widget.controller ??
      (_ownedController ??= PlacesAutocompleteController());

  bool get _isLauncherMode =>
      widget.fieldMode != PlacesAutocompleteFieldMode.inline;

  Duration get _debounceDuration =>
      widget.debounceDuration ?? _controller.debounceDuration;

  // Whether a search result may still be shown: the controller asks before
  // drawing one, and rejects it otherwise.
  bool get _canShowResults =>
      mounted &&
      widget.enabled &&
      !_isLauncherMode &&
      _controller.focusNode.hasFocus;

  void _rebuild() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _createOwnedClient();
    _attachController(_controller);
    _syncFocusMode();
  }

  @override
  void didUpdateWidget(PlacesAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final clientChanged =
        oldWidget.client != widget.client || oldWidget.apiKey != widget.apiKey;
    final previousOptions = _options;
    _options = _optionsOf(widget);
    final requestChanged =
        !_options._sameSearch(previousOptions) ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.fieldMode != widget.fieldMode;
    final previousClient = oldWidget.client ?? _ownedClient!;
    final retiredClient = clientChanged ? _ownedClient : null;
    if (clientChanged) {
      _createOwnedClient();
    }

    if (controllerChanged) {
      final previousController = oldWidget.controller ?? _ownedController!;
      _detachController(previousController, previousClient);
      _attachController(_controller);
    } else if (clientChanged || requestChanged) {
      _controller._configurationChanged(previousClient);
    }
    // After the controller has cancelled its in-flight work, so a late failure
    // is discarded as stale rather than reported.
    unawaited(retiredClient?.close());
    _syncFocusMode();
  }

  // The widget's search parameters, handed to the controller as one value.
  static PlacesAutocompleteOptions _optionsOf(PlacesAutocompleteField widget) =>
      PlacesAutocompleteOptions(
        languageCode: widget.languageCode,
        regionCode: widget.regionCode,
        origin: widget.origin,
        locationBias: widget.locationBias,
        locationRestriction: widget.locationRestriction,
        includedPrimaryTypes: widget.includedPrimaryTypes,
        includedRegionCodes: widget.includedRegionCodes,
        includePureServiceAreaBusinesses:
            widget.includePureServiceAreaBusinesses,
        includeFutureOpeningBusinesses: widget.includeFutureOpeningBusinesses,
        includeQueryPredictions: widget.includeQueryPredictions,
        maxSuggestions: widget.maxSuggestions,
        minInputLength: widget.minInputLength,
        fetchPlaceDetailsOnSelection: widget.fetchPlaceDetailsOnSelection,
        fetchTimeZoneOnSelection: widget.fetchTimeZoneOnSelection,
        selectionFields: widget.selectionFields,
        selectionLanguageCode: widget.selectionLanguageCode,
        selectionRegionCode: widget.selectionRegionCode,
        selectionTimeZoneAt: widget.selectionTimeZoneAt,
        selectionTimeZoneLanguageCode: widget.selectionTimeZoneLanguageCode,
      );

  void _attachController(PlacesAutocompleteController controller) {
    controller._attach(this);
    controller.focusNode.addListener(_onFocusChanged);
    controller.textController.addListener(_onTextControllerChanged);
    controller.addListener(_rebuild);
    _hasText = controller.textController.text.isNotEmpty;
  }

  void _detachController(
    PlacesAutocompleteController controller,
    PlacesClient client,
  ) {
    controller.focusNode.removeListener(_onFocusChanged);
    controller.textController.removeListener(_onTextControllerChanged);
    controller.removeListener(_rebuild);
    controller._detach(this, client);
  }

  void _syncFocusMode() {
    if (_isLauncherMode && _controller.focusNode.hasFocus) {
      _controller.focusNode.unfocus();
    }
    if (_isLauncherMode) {
      _controller._closeSearchWhileBuilding();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _detachController(_controller, _client);
    _ownedController?.dispose();
    unawaited(_ownedClient?.close());
    super.dispose();
  }

  // The inline suggestions are sized to the room the keyboard leaves. Their
  // OverlayPortal copies the overlay's view insets into the suggestions'
  // MediaQuery only when it rebuilds, and it rebuilds only when the field's
  // own MediaQuery changes — which, under a resizing Scaffold, has the bottom
  // inset removed (Flutter 3.44.0 to 3.47.7 and the 3.50 beta). Without this,
  // results open while the keyboard hides stay squeezed into the old room, and
  // results open while it shows run under it. Dialog and fullscreen fields
  // lay out in their route and need nothing.
  // ponytail: view metrics only; an inset changed by an app's own MediaQuery
  // is still missed. Drop this once OverlayPortal depends on those values.
  @override
  void didChangeMetrics() {
    if (_controller._open &&
        context.findAncestorWidgetOfExactType<PlacesAutocompleteOverlay>() ==
            null) {
      setState(() {});
    }
  }

  void _onFocusChanged() {
    final controller = _controller;
    if (_isLauncherMode) {
      // The launcher only opens the search. A custom field can still take
      // focus — on a tap, or when the closing route restores it — so give it
      // straight back.
      if (controller.focusNode.hasFocus) {
        controller.focusNode.unfocus();
      }
      return;
    }
    if (controller.focusNode.hasFocus) {
      return;
    }
    if (_suggestionPointerDown || controller._selectionInProgress) {
      return;
    }
    controller._abandonSearch();
  }

  void _onTextControllerChanged() {
    final hasText = _controller.textController.text.isNotEmpty;
    if (hasText == _hasText || !mounted) {
      return;
    }
    setState(() {
      _hasText = hasText;
    });
  }

  void _onUserInputChanged(String value) {
    // The default field cannot be edited in these states; a custom one
    // might ignore readOnly or enabled.
    if (_isLauncherMode || !widget.enabled) {
      return;
    }
    _controller._userInputChanged(value);
  }

  void _clearField() {
    // An open search can outlive its launcher, whose controller is then gone.
    if (mounted) {
      _controller.clear();
    }
    widget.onClearField?.call();
  }

  KeyEventResult _handleSuggestionKeyEvent(FocusNode node, KeyEvent event) {
    final controller = _controller;
    if (!controller._open || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      controller._abandonSearch();
      return KeyEventResult.handled;
    }
    final suggestions = controller._suggestions;
    if (suggestions.isEmpty) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      controller.moveHighlight(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      controller.moveHighlight(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final index = controller.highlightIndex;
      if (index >= 0 && index < suggestions.length) {
        unawaited(controller._select(suggestions[index]));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _openOverlay() async {
    final mode = switch (widget.fieldMode) {
      PlacesAutocompleteFieldMode.inline => null,
      PlacesAutocompleteFieldMode.dialog =>
        PlacesAutocompleteOverlayMode.dialog,
      PlacesAutocompleteFieldMode.fullscreen =>
        PlacesAutocompleteOverlayMode.fullscreen,
    };
    if (mode == null) {
      return;
    }

    final selection = await PlacesAutocompleteOverlay.show(
      context,
      // Given a key, the overlay owns its own client. A borrowed one would be
      // closed under it if this field's key changed, or the field was
      // disposed, while the overlay is open.
      client: widget.client,
      apiKey: widget.apiKey,
      initialText: _controller.textController.text,
      mode: mode,
      decoration: widget.decoration,
      strings: widget.strings,
      languageCode: widget.languageCode,
      regionCode: widget.regionCode,
      origin: widget.origin,
      locationBias: widget.locationBias,
      locationRestriction: widget.locationRestriction,
      includedPrimaryTypes: widget.includedPrimaryTypes,
      includedRegionCodes: widget.includedRegionCodes,
      includePureServiceAreaBusinesses: widget.includePureServiceAreaBusinesses,
      includeFutureOpeningBusinesses: widget.includeFutureOpeningBusinesses,
      fetchPlaceDetailsOnSelection: widget.fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: widget.fetchTimeZoneOnSelection,
      selectionFields: widget.selectionFields,
      selectionLanguageCode: widget.selectionLanguageCode,
      selectionRegionCode: widget.selectionRegionCode,
      selectionTimeZoneAt: widget.selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: widget.selectionTimeZoneLanguageCode,
      maxSuggestions: widget.maxSuggestions,
      minInputLength: widget.minInputLength,
      // The overlay gets its own controller, so pass the effective wait.
      debounceDuration: _debounceDuration,
      enabled: widget.enabled,
      showPoweredByGoogle: widget.showPoweredByGoogle,
      includeQueryPredictions: widget.includeQueryPredictions,
      keyboardType: widget._keyboardType,
      textInputAction: widget._textInputAction,
      textCapitalization: widget._textCapitalization,
      style: widget._style,
      strutStyle: widget._strutStyle,
      textAlign: widget._textAlign,
      textAlignVertical: widget._textAlignVertical,
      textDirection: widget._textDirection,
      showCursor: widget._showCursor,
      autocorrect: widget._autocorrect,
      smartDashesType: widget._smartDashesType,
      smartQuotesType: widget._smartQuotesType,
      enableSuggestions: widget._enableSuggestions,
      maxLength: widget._maxLength,
      maxLengthEnforcement: widget._maxLengthEnforcement,
      onChanged: widget._onChanged,
      onEditingComplete: widget._onEditingComplete,
      onSubmitted: widget._onSubmitted,
      onAppPrivateCommand: widget._onAppPrivateCommand,
      inputFormatters: widget._inputFormatters,
      ignorePointers: widget._ignorePointers,
      cursorWidth: widget._cursorWidth,
      cursorHeight: widget._cursorHeight,
      cursorRadius: widget._cursorRadius,
      cursorOpacityAnimates: widget._cursorOpacityAnimates,
      cursorColor: widget._cursorColor,
      cursorErrorColor: widget._cursorErrorColor,
      selectionHeightStyle: widget._selectionHeightStyle,
      selectionWidthStyle: widget._selectionWidthStyle,
      keyboardAppearance: widget._keyboardAppearance,
      scrollPadding: widget._scrollPadding,
      dragStartBehavior: widget._dragStartBehavior,
      enableInteractiveSelection: widget._enableInteractiveSelection,
      selectAllOnFocus: widget._selectAllOnFocus,
      selectionControls: widget._selectionControls,
      onTap: widget._onTap,
      onTapAlwaysCalled: widget._onTapAlwaysCalled,
      onTapOutside: widget._onTapOutside,
      onTapUpOutside: widget._onTapUpOutside,
      mouseCursor: widget._mouseCursor,
      buildCounter: widget._buildCounter,
      scrollController: widget._scrollController,
      scrollPhysics: widget._scrollPhysics,
      autofillHints: widget._autofillHints,
      contentInsertionConfiguration: widget._contentInsertionConfiguration,
      clipBehavior: widget._clipBehavior,
      stylusHandwritingEnabled: widget._stylusHandwritingEnabled,
      enableIMEPersonalizedLearning: widget._enableIMEPersonalizedLearning,
      enableInlinePrediction: widget._enableInlinePrediction,
      contextMenuBuilder: widget._contextMenuBuilder,
      spellCheckConfiguration: widget._spellCheckConfiguration,
      magnifierConfiguration: widget._magnifierConfiguration,
      hintLocales: widget._hintLocales,
      groupId: widget._groupId,
      undoController: widget._undoController,
      statesController: widget._statesController,
      fieldBuilder: widget.fieldBuilder,
      suggestionItemBuilder: widget.suggestionItemBuilder,
      suggestionsViewBuilder: widget.suggestionsViewBuilder,
      suggestionBuilder: widget.suggestionBuilder,
      onQuerySelection: widget.onQuerySelection,
      searchOnQuerySelection: widget.searchOnQuerySelection,
      // Clearing the search clears this field too, so it never shows a pick
      // that onClearField has reported gone.
      onClearField: _clearField,
      onError: widget.onError,
    );

    if (selection == null || !mounted) {
      return;
    }

    _controller.setSelection(selection);
    widget.onSelection?.call(selection);
  }

  @override
  Widget build(BuildContext context) {
    return PlacesDesignScope(child: Builder(builder: _buildField));
  }

  // Takes the context below PlacesDesignScope, so Theme.of and the
  // localizations resolve inside it.
  Widget _buildField(BuildContext context) {
    // Only PlacesAutocompleteOverlay builds a field inside itself, so its mode
    // picks the dedicated-route layouts. Elsewhere the field lays out inline.
    final overlayMode = context
        .findAncestorWidgetOfExactType<PlacesAutocompleteOverlay>()
        ?.mode;
    final fullscreen = overlayMode == PlacesAutocompleteOverlayMode.fullscreen;
    final controller = _controller;
    final selectionLoading = controller.selectionLoading;
    final interactive = widget.enabled && !selectionLoading;
    final field = PlacesFieldData(
      controller: _controller.textController,
      focusNode: _controller.focusNode,
      onChanged: _onUserInputChanged,
      onTap: _isLauncherMode && interactive ? _openOverlay : null,
      onClear: _hasText && interactive ? _clearField : null,
      enabled: widget.enabled,
      // Selection loading keeps the field enabled so focus and the
      // decoration survive. The progress indicator below and the
      // disabled clear button carry the loading affordance instead. Not
      // read-only when focus stays: that would close the keyboard.
      readOnly:
          _isLauncherMode || (selectionLoading && widget.unfocusOnSelection),
      autofocus: widget.autofocus && !_isLauncherMode,
      selectionLoading: selectionLoading,
      errorText: widget.decoration?.errorText,
      strings: widget.strings,
    );
    final customField = widget.fieldBuilder?.call(context, field);
    final textField = customField ?? _buildTextField(field, fullscreen);
    // A custom field shows selection loading itself.
    final progress = selectionLoading && customField == null
        ? const LinearProgressIndicator()
        : null;
    // The pointer guard covers the whole search surface, not just the
    // suggestion list. Tapping Retry moves focus to that button on some
    // platforms — notably web — and without this guard the focus listener
    // treats it as abandonment and closes the search UI before the retry can
    // run. The tap region keeps a click on the surface, on desktop, from
    // counting as a click outside the field.
    final surface = controller._open
        ? TextFieldTapRegion(
            groupId: widget._groupId,
            child: Listener(
              onPointerDown: (_) {
                _suggestionPointerDown = true;
              },
              onPointerUp: (_) {
                _suggestionPointerDown = false;
              },
              onPointerCancel: (_) {
                _suggestionPointerDown = false;
              },
              child: _buildSearchSurface(context, overlayMode),
            ),
          )
        : null;
    final input = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[textField, ?progress],
    );

    final layout = switch (overlayMode) {
      // Suggestions float over the page, anchored to the field, rather than
      // pushing the content below it down. Launchers show none, but keep the
      // portal mounted all the same.
      null => OverlayPortal.overlayChildLayoutBuilder(
        controller: _suggestionsPortal,
        overlayChildBuilder: (context, info) =>
            _buildAnchoredSurface(context, info, surface),
        child: input,
      ),
      // The field stays put and only the results scroll, edge to edge.
      PlacesAutocompleteOverlayMode.dialog => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: input,
          ),
          if (surface != null) Flexible(child: surface),
        ],
      ),
      // The field sits in the top bar, as in a platform search screen.
      PlacesAutocompleteOverlayMode.fullscreen => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildTopBar(context, textField),
          ?progress,
          Expanded(
            // The bar already took the top inset.
            child: SafeArea(
              top: false,
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: surface,
              ),
            ),
          ),
        ],
      ),
    };

    return Focus(onKeyEvent: _handleSuggestionKeyEvent, child: layout);
  }

  // The package's own field. Every TextField option is passed on under its
  // own name; the five composed ones keep the package's handling as well.
  Widget _buildTextField(PlacesFieldData field, bool inTopBar) {
    final w = widget;
    final focusNode = field.focusNode;
    // These attach to one field. A launcher stays mounted under its search, so
    // they go to the field the user types in.
    final editing = !_isLauncherMode;
    final onTapOutside = w._onTapOutside;
    final onTapUpOutside = w._onTapUpOutside;
    final contextMenuBuilder = w._contextMenuBuilder;
    final onTap = field.onTap;
    return TextField(
      controller: field.controller,
      focusNode: focusNode,
      canRequestFocus: !_isLauncherMode,
      enabled: field.enabled,
      readOnly: field.readOnly,
      autofocus: field.autofocus,
      decoration: _buildDecoration(inTopBar: inTopBar),
      onChanged: (value) {
        field.onChanged(value);
        w._onChanged?.call(value);
      },
      onTap: onTap == null && w._onTap == null
          ? null
          : () {
              onTap?.call();
              w._onTap?.call();
            },
      // TextField drops its own tap-outside handling when given a callback;
      // run it too, from inside the field, where Flutter registers it.
      onTapOutside: onTapOutside == null
          ? null
          : (event) {
              onTapOutside(event);
              _invokeInField(
                focusNode,
                EditableTextTapOutsideIntent(
                  focusNode: focusNode,
                  pointerDownEvent: event,
                ),
              );
            },
      onTapUpOutside: onTapUpOutside == null
          ? null
          : (event) {
              onTapUpOutside(event);
              _invokeInField(
                focusNode,
                EditableTextTapUpOutsideIntent(
                  focusNode: focusNode,
                  pointerUpEvent: event,
                ),
              );
            },
      // The menu is built in the root overlay, outside the field's scope.
      contextMenuBuilder: contextMenuBuilder == null
          ? null
          : (context, state) =>
                PlacesDesignScope(child: contextMenuBuilder(context, state)),
      keyboardType: w._keyboardType,
      textInputAction: w._textInputAction,
      textCapitalization: w._textCapitalization,
      style: w._style,
      strutStyle: w._strutStyle,
      textAlign: w._textAlign,
      textAlignVertical: w._textAlignVertical,
      textDirection: w._textDirection,
      showCursor: w._showCursor,
      autocorrect: w._autocorrect,
      smartDashesType: w._smartDashesType,
      smartQuotesType: w._smartQuotesType,
      enableSuggestions: w._enableSuggestions,
      maxLength: w._maxLength,
      maxLengthEnforcement: w._maxLengthEnforcement,
      onEditingComplete: w._onEditingComplete,
      onSubmitted: w._onSubmitted,
      onAppPrivateCommand: w._onAppPrivateCommand,
      inputFormatters: w._inputFormatters,
      ignorePointers: w._ignorePointers,
      cursorWidth: w._cursorWidth,
      cursorHeight: w._cursorHeight,
      cursorRadius: w._cursorRadius,
      cursorOpacityAnimates: w._cursorOpacityAnimates,
      cursorColor: w._cursorColor,
      cursorErrorColor: w._cursorErrorColor,
      selectionHeightStyle: w._selectionHeightStyle,
      selectionWidthStyle: w._selectionWidthStyle,
      keyboardAppearance: w._keyboardAppearance,
      scrollPadding: w._scrollPadding,
      dragStartBehavior: w._dragStartBehavior,
      enableInteractiveSelection: w._enableInteractiveSelection,
      selectAllOnFocus: w._selectAllOnFocus,
      selectionControls: w._selectionControls,
      onTapAlwaysCalled: w._onTapAlwaysCalled,
      mouseCursor: w._mouseCursor,
      buildCounter: w._buildCounter,
      scrollController: editing ? w._scrollController : null,
      scrollPhysics: w._scrollPhysics,
      autofillHints: w._autofillHints,
      contentInsertionConfiguration: w._contentInsertionConfiguration,
      clipBehavior: w._clipBehavior,
      stylusHandwritingEnabled: w._stylusHandwritingEnabled,
      enableIMEPersonalizedLearning: w._enableIMEPersonalizedLearning,
      enableInlinePrediction: w._enableInlinePrediction,
      spellCheckConfiguration: w._spellCheckConfiguration,
      magnifierConfiguration: w._magnifierConfiguration,
      hintLocales: w._hintLocales,
      groupId: w._groupId,
      undoController: editing ? w._undoController : null,
      statesController: editing ? w._statesController : null,
    );
  }

  static void _invokeInField(FocusNode focusNode, Intent intent) {
    final context = focusNode.context;
    if (context != null) {
      Actions.maybeInvoke(context, intent);
    }
  }

  static const double _anchoredGap = 8;

  // Positions the inline suggestions the way RawAutocomplete positions its
  // options: inside the part of the overlay that the keyboard and system UI
  // leave visible, on the requested side of the field or the one with more
  // room.
  Widget _buildAnchoredSurface(
    BuildContext context,
    OverlayChildLayoutInfo info,
    Widget? surface,
  ) {
    if (surface == null || info.childPaintTransform.determinant() == 0) {
      return const SizedBox.shrink();
    }
    final fieldSize = info.childSize;
    final visible = MediaQuery.paddingOf(context).deflateRect(
      MediaQuery.viewInsetsOf(
        context,
      ).deflateRect(Offset.zero & info.overlaySize),
    );
    final visibleInField = MatrixUtils.transformRect(
      info.childPaintTransform.clone()..invert(),
      visible,
    );
    final spaceAbove = -visibleInField.top - _anchoredGap;
    final spaceBelow = visibleInField.bottom - fieldSize.height - _anchoredGap;
    final opensUp = switch (widget.suggestionsViewOpenDirection) {
      OptionsViewOpenDirection.up => true,
      OptionsViewOpenDirection.down => false,
      OptionsViewOpenDirection.mostSpace => spaceAbove > spaceBelow,
    };
    // Never smaller than one row; if the field is that cramped, the
    // suggestions overlap it rather than leave the screen.
    final height = math.max(
      opensUp ? spaceAbove : spaceBelow,
      kMinInteractiveDimension,
    );
    final top = opensUp ? visibleInField.top : visibleInField.bottom - height;
    return Transform(
      transform: info.childPaintTransform.clone()
        ..translateByDouble(0, top, 0, 1),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: fieldSize.width,
          height: height,
          child: Align(
            alignment: opensUp
                ? AlignmentDirectional.bottomStart
                : AlignmentDirectional.topStart,
            // Scrolling the suggestions is not scrolling the page: keep it
            // from the page's app bar, which would tint as if scrolled under.
            child: NotificationListener<Notification>(
              onNotification: (notification) =>
                  notification is ScrollNotification ||
                  notification is ScrollMetricsNotification,
              child: surface,
            ),
          ),
        ),
      ),
    );
  }

  // Not an AppBar: its toolbar is a fixed height that clips a field with a
  // label or an error line, and an app's appBarTheme colours would put the
  // field's onSurface text on the app's brand colour. This bar grows with the
  // field and takes its colours from the colour scheme, as a search view does.
  Widget _buildTopBar(BuildContext context, Widget textField) {
    final background = Theme.of(context).colorScheme.surface;
    final dark =
        ThemeData.estimateBrightnessForColor(background) == Brightness.dark;
    // The platform's back icon, as platform search screens use, so it cannot
    // be mistaken for the clear button. The label is the caller's.
    final dismiss = (ModalRoute.of(context)?.impliesAppBarDismissal ?? false)
        ? IconButton(
            tooltip: widget.strings.closeLabel,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const BackButtonIcon(),
          )
        : null;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: const Color(0x00000000),
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      ),
      child: Material(
        color: background,
        child: SafeArea(
          bottom: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: kToolbarHeight),
            child: Padding(
              // Vertical room for an outlined field's floating label.
              padding: EdgeInsetsDirectional.fromSTEB(
                dismiss == null ? 16 : 4,
                8,
                8,
                8,
              ),
              child: Row(
                children: <Widget>[
                  ?dismiss,
                  if (dismiss != null) const SizedBox(width: 4),
                  Expanded(child: textField),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSurface(
    BuildContext context,
    PlacesAutocompleteOverlayMode? overlayMode,
  ) {
    final controller = _controller;
    final suggestions = controller.suggestions;
    final status = controller.status;
    if (status == null) {
      return const SizedBox.shrink();
    }
    // Inline, the results float as a card by the field. In a dialog or
    // fullscreen route they sit directly on the route's surface.
    final framed = overlayMode == null;
    final attribution = widget.showPoweredByGoogle
        ? _PoweredByGoogleAttribution(
            semanticLabel: widget.strings.poweredByGoogleLabel,
          )
        : null;
    final items = <Widget>[
      for (var index = 0; index < suggestions.length; index++)
        _RevealWhenHighlighted(
          highlighted: index == controller.highlightIndex,
          child: _buildSuggestionItem(context, suggestions[index], index),
        ),
    ];
    final defaultView = switch (status) {
      PlacesSuggestionsStatus.loading => _InfoTile(
        framed: framed,
        child: Row(
          children: <Widget>[
            const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.strings.loadingText)),
          ],
        ),
      ),
      PlacesSuggestionsStatus.error => _InfoTile(
        framed: framed,
        child: Row(
          children: <Widget>[
            Expanded(child: Text(widget.strings.errorText)),
            TextButton(
              onPressed: controller._retrySearch,
              child: Text(widget.strings.retryText),
            ),
          ],
        ),
      ),
      PlacesSuggestionsStatus.empty => _InfoTile(
        framed: framed,
        child: Text(widget.strings.noResultsText),
      ),
      PlacesSuggestionsStatus.results => _buildResults(
        context,
        framed: framed,
        items: items,
        attribution: attribution,
      ),
    };
    return widget.suggestionsViewBuilder?.call(
          context,
          PlacesSuggestionsViewData(
            status: status,
            suggestions: suggestions,
            items: items,
            error: controller.error,
            onRetry: controller._retrySearch,
            attribution: attribution,
            defaultView: defaultView,
            strings: widget.strings,
          ),
        ) ??
        defaultView;
  }

  Widget _buildResults(
    BuildContext context, {
    required bool framed,
    required List<Widget> items,
    required Widget? attribution,
  }) {
    // Only the rows scroll. The attribution follows a short list and stays
    // in view below a long one, so it is never scrolled away from results.
    final results = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Flexible(
          child: ListView(
            // Sizes to its rows, at most five, so the attribution can follow.
            shrinkWrap: true,
            // Inline it floats over someone else's page; never claim that
            // page's PrimaryScrollController.
            primary: false,
            padding: EdgeInsets.zero,
            children: items,
          ),
        ),
        if (attribution != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: attribution,
            ),
          ),
      ],
    );
    return framed ? _InfoTile.card(context, results) : results;
  }

  Widget _buildSuggestionItem(
    BuildContext context,
    AutocompleteSuggestion suggestion,
    int index,
  ) {
    final item = PlacesSuggestionItemData(
      suggestion: suggestion,
      highlighted: index == _controller.highlightIndex,
      onSelected: () => _controller._select(suggestion),
      strings: widget.strings,
    );
    return widget.suggestionItemBuilder?.call(context, item) ??
        _buildDefaultSuggestionItem(context, item);
  }

  Widget _buildDefaultSuggestionItem(
    BuildContext context,
    PlacesSuggestionItemData item,
  ) {
    final strings = item.strings;
    // The keyboard highlight is not a selection, so not ListTile.selected:
    // that recolours the text and ignores tileColor. Flutter's own
    // Autocomplete marks it with the theme's focus colour.
    final tileColor = item.highlighted ? Theme.of(context).focusColor : null;
    final (label, tile) = switch (item.suggestion) {
      QuerySuggestion(:final fullText, :final displayText) => (
        '${strings.querySuggestionLabel}: $displayText',
        ListTile(
          tileColor: tileColor,
          leading: const Icon(Icons.search),
          onTap: item.onSelected,
          title: _structuredText(fullText),
        ),
      ),
      final PlaceSuggestion place => (
        '${strings.placeSuggestionLabel}: ${place.displayText}',
        ListTile(
          tileColor: tileColor,
          onTap: item.onSelected,
          title:
              widget.suggestionBuilder?.call(context, place) ??
              _structuredText(place.primaryText),
          subtitle: place.secondaryText == null
              ? null
              : _structuredText(place.secondaryText!),
          trailing: place.distanceMeters == null
              ? null
              : Text('${place.distanceMeters} ${strings.distanceUnitMeters}'),
        ),
      ),
    };
    // Its own Material, so the tile colour and ink paint here even inside a
    // custom suggestions view with no Material of its own.
    return Semantics(
      button: true,
      label: label,
      child: Material(type: MaterialType.transparency, child: tile),
    );
  }

  // Matched characters are bold. The rest inherits the tile's text style, so
  // a ListTileTheme restyles titles and subtitles alike.
  Widget _structuredText(StructuredText value) {
    if (value.matches.isEmpty) {
      return Text(value.text);
    }
    const highlightStyle = TextStyle(fontWeight: FontWeight.w700);
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final match in value.matches) {
      final start = match.startOffset.clamp(0, value.text.length);
      final end = match.endOffset.clamp(start, value.text.length);
      if (start > cursor) {
        spans.add(TextSpan(text: value.text.substring(cursor, start)));
      }
      if (end > start) {
        spans.add(
          TextSpan(
            text: value.text.substring(start, end),
            style: highlightStyle,
          ),
        );
      }
      cursor = end;
    }
    if (cursor < value.text.length) {
      spans.add(TextSpan(text: value.text.substring(cursor)));
    }
    return Text.rich(TextSpan(children: spans));
  }

  InputDecoration _buildDecoration({required bool inTopBar}) {
    var baseDecoration = widget.decoration ?? const InputDecoration();
    if (inTopBar &&
        baseDecoration.border == null &&
        baseDecoration.enabledBorder == null &&
        baseDecoration.focusedBorder == null) {
      // No border in the top bar unless the decoration sets one — and none
      // from the theme's per-state borders either.
      baseDecoration = baseDecoration.copyWith(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
      );
    }
    final clearButton = _hasText
        ? IconButton(
            onPressed: widget.enabled && !_controller.selectionLoading
                ? _clearField
                : null,
            icon: const Icon(Icons.clear),
            tooltip: widget.strings.clearLabel,
          )
        : null;

    final userSuffix = baseDecoration.suffix;
    final userSuffixIcon = baseDecoration.suffixIcon;
    final effectiveSuffix = clearButton == null
        ? userSuffix
        : _mergeSuffix(
            suffix: userSuffix,
            suffixIcon: userSuffixIcon,
            suffixIconConstraints: baseDecoration.suffixIconConstraints,
          );
    final effectiveSuffixIcon = clearButton ?? userSuffixIcon;

    return baseDecoration.copyWith(
      hintText: baseDecoration.hintText ?? widget.strings.searchHint,
      suffix: effectiveSuffix,
      suffixIcon: effectiveSuffixIcon,
    );
  }

  Widget? _mergeSuffix({
    Widget? suffix,
    Widget? suffixIcon,
    BoxConstraints? suffixIconConstraints,
  }) {
    if (suffix == null && suffixIcon == null) {
      return null;
    }

    final items = <Widget>[];
    if (suffix != null) {
      items.add(suffix);
    }
    if (suffixIcon != null) {
      items.add(
        _SuffixIconProxy(constraints: suffixIconConstraints, child: suffixIcon),
      );
    }

    if (items.length == 1) {
      return items.single;
    }

    return Wrap(
      spacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: items,
    );
  }
}

/// Scrolls its row into view when the keyboard highlights it.
class _RevealWhenHighlighted extends StatefulWidget {
  const _RevealWhenHighlighted({
    required this.highlighted,
    required this.child,
  });

  final bool highlighted;
  final Widget child;

  @override
  State<_RevealWhenHighlighted> createState() => _RevealWhenHighlightedState();
}

class _RevealWhenHighlightedState extends State<_RevealWhenHighlighted> {
  @override
  void didUpdateWidget(_RevealWhenHighlighted oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlighted && !oldWidget.highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
    }
  }

  void _reveal() {
    if (!mounted) {
      return;
    }
    final row = context.findRenderObject();
    final scrollable = Scrollable.maybeOf(context);
    final scrollableBox = scrollable?.context.findRenderObject();
    // Inline, the rows inherit from the field's place on the page, so the
    // nearest Scrollable can be the page's own. Scroll only one that holds
    // the row — as Flutter's Autocomplete does, centring it.
    for (var node = row?.parent; node != null; node = node.parent) {
      if (identical(node, scrollableBox)) {
        unawaited(scrollable!.position.ensureVisible(row!, alignment: 0.5));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.framed, required this.child});

  final bool framed;
  final Widget child;

  // The inline surface floats over the page, so it is raised off it.
  static Widget card(BuildContext context, Widget child) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(12),
    elevation: 3,
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: const EdgeInsets.all(16), child: child);
    return framed ? card(context, content) : content;
  }
}

class _PoweredByGoogleAttribution extends StatelessWidget {
  const _PoweredByGoogleAttribution({required this.semanticLabel});

  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final assetName = brightness == Brightness.dark
        ? 'assets/google_dark.png'
        : 'assets/google_light.png';
    return Image.asset(
      assetName,
      package: 'google_places_sdk_flutter',
      height: 18,
      semanticLabel: semanticLabel,
    );
  }
}

class _SuffixIconProxy extends StatelessWidget {
  const _SuffixIconProxy({required this.child, this.constraints});

  final Widget child;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    final effectiveConstraints =
        constraints ?? const BoxConstraints(minWidth: 48, minHeight: 48);

    return ConstrainedBox(
      constraints: effectiveConstraints,
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    );
  }
}
