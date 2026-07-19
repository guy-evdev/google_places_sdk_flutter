import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import '../places_cancellation_token.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_overlay.dart';
import 'places_strings.dart';

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
/// Example:
/// ```dart
/// PlacesAutocompleteField(
///   client: client,
///   languageCode: 'en',
///   regionCode: 'us',
///   includedPrimaryTypes: const <String>['restaurant'],
///   fetchPlaceDetailsOnSelection: true,
///   onSelection: (selection) {
///     debugPrint(selection.displayText);
///   },
/// )
/// ```
class PlacesAutocompleteField extends StatefulWidget {
  /// Creates a Places autocomplete field or launcher.
  const PlacesAutocompleteField({
    super.key,
    required this.client,
    this.controller,
    this.decoration,
    this.strings = const PlacesStrings(),
    this.languageCode,
    this.regionCode,
    this.locationBias,
    this.locationRestriction,
    this.includedPrimaryTypes = const <String>[],
    this.includedRegionCodes = const <String>[],
    this.includePureServiceAreaBusinesses = false,
    this.fetchPlaceDetailsOnSelection = false,
    this.fetchTimeZoneOnSelection = false,
    this.selectionFields = PlaceFieldPresets.recommended,
    this.selectionLanguageCode,
    this.selectionRegionCode,
    this.selectionTimeZoneAt,
    this.selectionTimeZoneLanguageCode,
    this.fieldMode = PlacesAutocompleteFieldMode.inline,
    this.onSelection,
    this.onClearField,
    this.onError,
    this.maxSuggestions = 5,
    this.enabled = true,
    this.autofocus = false,
    this.showPoweredByGoogle = true,
    this.includeQueryPredictions = false,
    this.onQuerySelection,
    this.suggestionBuilder,
  });

  /// Client used for autocomplete, place-details, and optional time-zone calls.
  final PlacesClient client;

  /// Optional external controller for coordinating text, focus, and selection.
  final PlacesAutocompleteController? controller;

  /// Optional base decoration for the text field UI.
  final InputDecoration? decoration;

  /// Localized strings used by the field and its overlays.
  final PlacesStrings strings;

  /// Preferred BCP-47 language code for results, such as `'en'` or `'he'`.
  final String? languageCode;

  /// Preferred CLDR region code for results, such as `'us'` or `'il'`.
  final String? regionCode;

  /// Soft geographic preference applied to autocomplete results.
  final LocationBias? locationBias;

  /// Hard geographic restriction applied to autocomplete results.
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

  /// Whether a selected suggestion should be resolved into [PlaceData] before
  /// [onSelection] is called.
  final bool fetchPlaceDetailsOnSelection;

  /// Whether a selected suggestion should also resolve time-zone metadata.
  ///
  /// This implicitly resolves place details first because time-zone lookup
  /// requires geographic coordinates.
  final bool fetchTimeZoneOnSelection;

  /// The fields to request when [fetchPlaceDetailsOnSelection] is enabled.
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

  /// Called after the field's clear action is pressed.
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

  /// Whether the field can be interacted with.
  final bool enabled;

  /// Whether the field should request focus automatically.
  final bool autofocus;

  /// Whether the Powered by Google attribution should be shown.
  final bool showPoweredByGoogle;

  /// Whether autocomplete should include query suggestions as well as places.
  final bool includeQueryPredictions;

  /// Called when the user selects a query suggestion.
  final ValueChanged<QuerySuggestion>? onQuerySelection;

  /// Optional builder for rendering custom suggestion tiles.
  final Widget Function(BuildContext context, PlaceSuggestion suggestion)?
  suggestionBuilder;

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  PlacesAutocompleteController? _ownedController;
  Timer? _debounce;
  List<AutocompleteSuggestion> _suggestions = const <AutocompleteSuggestion>[];
  Object? _error;
  bool _loading = false;
  bool _selectionLoading = false;
  bool _searchUiVisible = false;
  bool _suggestionPointerDown = false;
  bool _hasText = false;
  int _highlightedSuggestionIndex = -1;
  int _searchGeneration = 0;
  int _selectionGeneration = 0;
  bool _selectionInProgress = false;
  PlacesCancellationToken? _searchCancellationToken;
  PlacesCancellationToken? _selectionCancellationToken;
  AutocompleteSessionToken? _observedSessionToken;

  PlacesAutocompleteController get _controller =>
      widget.controller ??
      (_ownedController ??= PlacesAutocompleteController());

  bool get _isLauncherMode =>
      widget.fieldMode != PlacesAutocompleteFieldMode.inline;

  bool get _shouldResolvePlaceOnSelection =>
      widget.fetchPlaceDetailsOnSelection || widget.fetchTimeZoneOnSelection;

  Set<PlaceField> get _effectiveSelectionFields =>
      widget.fetchTimeZoneOnSelection
      ? <PlaceField>{...widget.selectionFields, PlaceField.location}
      : widget.selectionFields;

  int get _effectiveMaxSuggestions => widget.maxSuggestions.clamp(1, 5);

  @override
  void initState() {
    super.initState();
    _attachController(_controller);
    _syncFocusMode();
  }

  @override
  void didUpdateWidget(PlacesAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final clientChanged = oldWidget.client != widget.client;
    final requestChanged = _requestConfigurationChanged(oldWidget);

    if (controllerChanged) {
      final previousController = oldWidget.controller ?? _ownedController!;
      _endObservedSession(oldWidget.client);
      _detachController(previousController);
      _invalidateAsyncWork();
      _attachController(_controller);
    } else if (clientChanged || requestChanged) {
      _endObservedSession(clientChanged ? oldWidget.client : widget.client);
      _controller.resetSession(notify: false);
      _observedSessionToken = _controller.sessionToken;
      _invalidateAsyncWork();
    }
    _syncFocusMode();
  }

  bool _requestConfigurationChanged(PlacesAutocompleteField oldWidget) {
    return oldWidget.languageCode != widget.languageCode ||
        oldWidget.regionCode != widget.regionCode ||
        oldWidget.locationBias != widget.locationBias ||
        oldWidget.locationRestriction != widget.locationRestriction ||
        !listEquals(
          oldWidget.includedPrimaryTypes,
          widget.includedPrimaryTypes,
        ) ||
        !listEquals(
          oldWidget.includedRegionCodes,
          widget.includedRegionCodes,
        ) ||
        oldWidget.includePureServiceAreaBusinesses !=
            widget.includePureServiceAreaBusinesses ||
        oldWidget.fetchPlaceDetailsOnSelection !=
            widget.fetchPlaceDetailsOnSelection ||
        oldWidget.fetchTimeZoneOnSelection != widget.fetchTimeZoneOnSelection ||
        !setEquals(oldWidget.selectionFields, widget.selectionFields) ||
        oldWidget.selectionLanguageCode != widget.selectionLanguageCode ||
        oldWidget.selectionRegionCode != widget.selectionRegionCode ||
        oldWidget.selectionTimeZoneAt != widget.selectionTimeZoneAt ||
        oldWidget.selectionTimeZoneLanguageCode !=
            widget.selectionTimeZoneLanguageCode ||
        oldWidget.includeQueryPredictions != widget.includeQueryPredictions ||
        oldWidget.maxSuggestions != widget.maxSuggestions ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.fieldMode != widget.fieldMode;
  }

  void _attachController(PlacesAutocompleteController controller) {
    controller.focusNode.addListener(_onFocusChanged);
    controller.textController.addListener(_onTextControllerChanged);
    controller.addListener(_onControllerChanged);
    _observedSessionToken = controller.sessionToken;
    _hasText = controller.textController.text.isNotEmpty;
  }

  void _detachController(PlacesAutocompleteController controller) {
    controller.focusNode.removeListener(_onFocusChanged);
    controller.textController.removeListener(_onTextControllerChanged);
    controller.removeListener(_onControllerChanged);
  }

  void _syncFocusMode() {
    if (_isLauncherMode && _controller.focusNode.hasFocus) {
      _controller.focusNode.unfocus();
    }
    if (_isLauncherMode) {
      _closeSearchUi();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCancellationToken?.cancel();
    _selectionCancellationToken?.cancel();
    _searchGeneration++;
    _selectionGeneration++;
    final controller = _controller;
    _endObservedSession(widget.client);
    _detachController(controller);
    _ownedController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final currentToken = _controller.sessionToken;
    final previousToken = _observedSessionToken;
    if (previousToken?.value == currentToken.value) {
      return;
    }
    _observedSessionToken = currentToken;
    if (previousToken != null) {
      unawaited(widget.client.endAutocompleteSession(previousToken));
    }
    _invalidateAsyncWork();
  }

  void _endObservedSession(PlacesClient client) {
    final token = _observedSessionToken;
    _observedSessionToken = null;
    if (token != null) {
      unawaited(client.endAutocompleteSession(token));
    }
  }

  void _invalidateAsyncWork() {
    _debounce?.cancel();
    _searchCancellationToken?.cancel();
    _searchCancellationToken = null;
    _selectionCancellationToken?.cancel();
    _selectionCancellationToken = null;
    _searchGeneration++;
    _selectionGeneration++;
    _selectionInProgress = false;
    if (!mounted) {
      return;
    }
    setState(() {
      _searchUiVisible = false;
      _loading = false;
      _selectionLoading = false;
      _error = null;
      _suggestions = const <AutocompleteSuggestion>[];
      _highlightedSuggestionIndex = -1;
    });
  }

  void _onFocusChanged() {
    if (_controller.focusNode.hasFocus || _isLauncherMode) {
      return;
    }
    if (_suggestionPointerDown || _selectionInProgress) {
      return;
    }
    final hadActiveSession =
        _searchUiVisible || _loading || _suggestions.isNotEmpty;
    _closeSearchUi();
    if (hadActiveSession) {
      _controller.resetSession();
    }
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
    if (_isLauncherMode) {
      return;
    }
    if (_controller.selectedSelection != null) {
      _controller.clearSelection();
      widget.onClearField?.call();
    }
    _debounce?.cancel();
    final input = value.trim();
    if (input.isEmpty) {
      final hadActiveSession =
          _searchUiVisible || _loading || _suggestions.isNotEmpty;
      _closeSearchUi();
      if (hadActiveSession) {
        _controller.resetSession();
      }
      return;
    }
    setState(() {
      _searchUiVisible = true;
      _loading = false;
      _error = null;
      _highlightedSuggestionIndex = -1;
    });
    final generation = ++_searchGeneration;
    _debounce = Timer(_controller.debounceDuration, () {
      unawaited(_search(input, generation));
    });
  }

  void _invalidateSearches() {
    _searchCancellationToken?.cancel();
    _searchCancellationToken = null;
    _searchGeneration++;
  }

  bool _isActiveSearch(String input, int generation) {
    return mounted &&
        generation == _searchGeneration &&
        _searchUiVisible &&
        widget.enabled &&
        !_isLauncherMode &&
        _controller.focusNode.hasFocus &&
        _controller.textController.text.trim() == input;
  }

  void _closeSearchUi() {
    _debounce?.cancel();
    _invalidateSearches();
    if (!mounted) {
      return;
    }
    setState(() {
      _searchUiVisible = false;
      _loading = false;
      _error = null;
      _suggestions = const <AutocompleteSuggestion>[];
      _highlightedSuggestionIndex = -1;
    });
  }

  Future<void> _search(String input, int generation) async {
    if (!_isActiveSearch(input, generation)) {
      return;
    }
    _searchCancellationToken?.cancel();
    final cancellationToken = PlacesCancellationToken();
    _searchCancellationToken = cancellationToken;
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final request = AutocompleteRequest(
        input: input,
        inputOffset: _unicodeInputOffset(input),
        sessionToken: _controller.sessionToken,
        languageCode: widget.languageCode,
        regionCode: widget.regionCode,
        locationBias: widget.locationBias,
        locationRestriction: widget.locationRestriction,
        includedPrimaryTypes: widget.includedPrimaryTypes,
        includedRegionCodes: widget.includedRegionCodes,
        includePureServiceAreaBusinesses:
            widget.includePureServiceAreaBusinesses,
        includeQueryPredictions: widget.includeQueryPredictions,
      );
      final suggestions = widget.includeQueryPredictions
          ? await widget.client.autocompleteSuggestions(
              request,
              cancellationToken: cancellationToken,
            )
          : await widget.client.autocomplete(
              request,
              cancellationToken: cancellationToken,
            );
      if (!_isActiveSearch(input, generation)) {
        return;
      }
      final limitedSuggestions = suggestions
          .take(_effectiveMaxSuggestions)
          .toList(growable: false);
      setState(() {
        _loading = false;
        _suggestions = limitedSuggestions;
        _highlightedSuggestionIndex = limitedSuggestions.isEmpty ? -1 : 0;
      });
    } catch (error) {
      if (!_isActiveSearch(input, generation)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
        _suggestions = const <AutocompleteSuggestion>[];
        _highlightedSuggestionIndex = -1;
      });
      widget.onError?.call(error);
    } finally {
      if (identical(_searchCancellationToken, cancellationToken)) {
        _searchCancellationToken = null;
      }
    }
  }

  void _retrySearch() {
    final input = _controller.textController.text.trim();
    if (input.isEmpty || !_controller.focusNode.hasFocus) {
      return;
    }
    final generation = ++_searchGeneration;
    unawaited(_search(input, generation));
  }

  int? _unicodeInputOffset(String input) {
    final rawInput = _controller.textController.text;
    final selectionOffset = _controller.textController.selection.extentOffset;
    final inputStart = rawInput.indexOf(input);
    if (selectionOffset < 0 || inputStart < 0) {
      return null;
    }
    final localCodeUnitOffset = (selectionOffset - inputStart).clamp(
      0,
      input.length,
    );
    return input.substring(0, localCodeUnitOffset).runes.length;
  }

  void _clearField() {
    _controller.clear();
    _closeSearchUi();
    widget.onClearField?.call();
  }

  Future<void> _handleSuggestionTap(AutocompleteSuggestion suggestion) async {
    if (_selectionInProgress) {
      return;
    }
    if (suggestion is QuerySuggestion) {
      _closeSearchUi();
      _controller.textController
        ..text = suggestion.displayText
        ..selection = TextSelection.collapsed(
          offset: suggestion.displayText.length,
        );
      widget.onQuerySelection?.call(suggestion);
      _controller.resetSession();
      return;
    }
    if (suggestion is! PlaceSuggestion) {
      return;
    }
    final client = widget.client;
    final controller = _controller;
    final sessionToken = controller.sessionToken;
    final generation = ++_selectionGeneration;
    _selectionCancellationToken?.cancel();
    final cancellationToken = PlacesCancellationToken();
    _selectionCancellationToken = cancellationToken;
    _selectionInProgress = true;
    _closeSearchUi();
    final initialSelection = PlaceSelection(
      suggestion: suggestion,
      sessionToken: sessionToken,
    );
    controller.setSelection(initialSelection);
    controller.focusNode.unfocus();
    try {
      if (!_shouldResolvePlaceOnSelection) {
        if (_isActiveSelection(generation, client, controller)) {
          widget.onSelection?.call(initialSelection);
        }
        return;
      }
      setState(() {
        _selectionLoading = true;
      });
      final place = await client.fetchPlace(
        PlaceDetailsRequest(
          placeId: suggestion.placeId,
          fields: _effectiveSelectionFields,
          languageCode: widget.selectionLanguageCode ?? widget.languageCode,
          regionCode: widget.selectionRegionCode ?? widget.regionCode,
          sessionToken: sessionToken,
        ),
        cancellationToken: cancellationToken,
      );
      if (!_isActiveSelection(generation, client, controller)) {
        return;
      }
      PlaceTimeZoneData? timeZone;
      if (widget.fetchTimeZoneOnSelection) {
        timeZone = await client.fetchTimeZoneForPlace(
          place,
          timestamp: widget.selectionTimeZoneAt,
          languageCode:
              widget.selectionTimeZoneLanguageCode ??
              widget.selectionLanguageCode ??
              widget.languageCode,
          cancellationToken: cancellationToken,
        );
        if (!_isActiveSelection(generation, client, controller)) {
          return;
        }
      }
      final resolvedSelection = PlaceSelection(
        suggestion: suggestion,
        sessionToken: sessionToken,
        place: place,
        timeZone: timeZone,
      );
      controller.setSelection(resolvedSelection, updateText: false);
      widget.onSelection?.call(resolvedSelection);
    } catch (error) {
      if (_isActiveSelection(generation, client, controller)) {
        widget.onError?.call(error);
      }
    } finally {
      if (identical(_selectionCancellationToken, cancellationToken)) {
        _selectionCancellationToken = null;
      }
      if (_isActiveSelection(generation, client, controller)) {
        _selectionInProgress = false;
        setState(() {
          _selectionLoading = false;
        });
      }
      if (controller.sessionToken.value == sessionToken.value &&
          mounted &&
          identical(controller, _controller) &&
          identical(client, widget.client)) {
        controller.resetSession();
      } else {
        unawaited(client.endAutocompleteSession(sessionToken));
      }
    }
  }

  bool _isActiveSelection(
    int generation,
    PlacesClient client,
    PlacesAutocompleteController controller,
  ) {
    return mounted &&
        generation == _selectionGeneration &&
        identical(client, widget.client) &&
        identical(controller, _controller);
  }

  KeyEventResult _handleSuggestionKeyEvent(FocusNode node, KeyEvent event) {
    if (!_searchUiVisible || _suggestions.isEmpty || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _moveHighlightedSuggestion(1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _moveHighlightedSuggestion(-1);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      final index = _highlightedSuggestionIndex;
      if (index >= 0 && index < _suggestions.length) {
        unawaited(_handleSuggestionTap(_suggestions[index]));
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _moveHighlightedSuggestion(int delta) {
    if (_suggestions.isEmpty) {
      return;
    }
    setState(() {
      _highlightedSuggestionIndex =
          (_highlightedSuggestionIndex + delta) % _suggestions.length;
      if (_highlightedSuggestionIndex < 0) {
        _highlightedSuggestionIndex += _suggestions.length;
      }
    });
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
      client: widget.client,
      initialText: _controller.textController.text,
      mode: mode,
      strings: widget.strings,
      languageCode: widget.languageCode,
      regionCode: widget.regionCode,
      locationBias: widget.locationBias,
      locationRestriction: widget.locationRestriction,
      includedPrimaryTypes: widget.includedPrimaryTypes,
      includedRegionCodes: widget.includedRegionCodes,
      includePureServiceAreaBusinesses: widget.includePureServiceAreaBusinesses,
      fetchPlaceDetailsOnSelection: widget.fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: widget.fetchTimeZoneOnSelection,
      selectionFields: widget.selectionFields,
      selectionLanguageCode: widget.selectionLanguageCode,
      selectionRegionCode: widget.selectionRegionCode,
      selectionTimeZoneAt: widget.selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: widget.selectionTimeZoneLanguageCode,
      maxSuggestions: widget.maxSuggestions,
      includeQueryPredictions: widget.includeQueryPredictions,
      onQuerySelection: widget.onQuerySelection,
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
    final theme = Theme.of(context);
    final decoration = _buildDecoration();

    return Focus(
      onKeyEvent: _handleSuggestionKeyEvent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller.textController,
            focusNode: _controller.focusNode,
            canRequestFocus: !_isLauncherMode,
            enabled: widget.enabled && !_selectionLoading,
            readOnly: _isLauncherMode,
            autofocus: widget.autofocus,
            onChanged: _onUserInputChanged,
            onTap: _isLauncherMode && widget.enabled ? _openOverlay : null,
            decoration: decoration,
          ),
          if (_selectionLoading) const LinearProgressIndicator(),
          if (_searchUiVisible) ...<Widget>[
            const SizedBox(height: 8),
            if (_loading)
              _InfoTile(
                child: Row(
                  children: <Widget>[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(widget.strings.loadingText)),
                  ],
                ),
              )
            else if (_error != null)
              _InfoTile(
                child: Row(
                  children: <Widget>[
                    Expanded(child: Text(widget.strings.errorText)),
                    TextButton(
                      onPressed: _retrySearch,
                      child: Text(widget.strings.retryText),
                    ),
                  ],
                ),
              )
            else if (_suggestions.isEmpty &&
                _controller.textController.text.trim().isNotEmpty)
              _InfoTile(child: Text(widget.strings.noResultsText))
            else if (_suggestions.isNotEmpty)
              Material(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final indexed in _suggestions.indexed)
                        _buildSuggestionTile(context, indexed.$2, indexed.$1),
                      if (widget.showPoweredByGoogle)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: _PoweredByGoogleAttribution(
                              semanticLabel:
                                  widget.strings.poweredByGoogleLabel,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionTile(
    BuildContext context,
    AutocompleteSuggestion suggestion,
    int index,
  ) {
    final theme = Theme.of(context);
    final selected = index == _highlightedSuggestionIndex;
    final backgroundColor = selected
        ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.55)
        : null;

    if (suggestion is QuerySuggestion) {
      return Semantics(
        button: true,
        label:
            '${widget.strings.querySuggestionLabel}: '
            '${suggestion.displayText}',
        child: ListTile(
          selected: selected,
          tileColor: backgroundColor,
          leading: const Icon(Icons.search),
          onTap: () => _handleSuggestionTap(suggestion),
          title: _structuredText(suggestion.fullText, theme),
        ),
      );
    }

    final place = suggestion as PlaceSuggestion;
    return Semantics(
      button: true,
      label: '${widget.strings.placeSuggestionLabel}: ${place.displayText}',
      child: ListTile(
        selected: selected,
        tileColor: backgroundColor,
        onTap: () => _handleSuggestionTap(place),
        title:
            widget.suggestionBuilder?.call(context, place) ??
            _structuredText(place.primaryText, theme),
        subtitle: place.secondaryText == null
            ? null
            : _structuredText(place.secondaryText!, theme),
        trailing: place.distanceMeters == null
            ? null
            : Text('${place.distanceMeters} m'),
      ),
    );
  }

  Widget _structuredText(StructuredText value, ThemeData theme) {
    if (value.matches.isEmpty) {
      return Text(value.text);
    }
    final baseStyle = theme.textTheme.bodyLarge;
    final highlightStyle = baseStyle?.copyWith(fontWeight: FontWeight.w700);
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
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }

  InputDecoration _buildDecoration() {
    final baseDecoration = widget.decoration ?? const InputDecoration();
    final clearButton = _hasText
        ? IconButton(
            onPressed: widget.enabled && !_selectionLoading
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

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
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
