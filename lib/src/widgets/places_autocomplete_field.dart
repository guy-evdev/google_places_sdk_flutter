import 'dart:async';

import 'package:flutter/material.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_overlay.dart';
import 'places_strings.dart';

/// Controls how [PlacesAutocompleteField] behaves.
///
/// - [inline]: a regular editable text field with inline suggestions.
/// - [dialog]: a read-only launcher field that opens dialog search UI.
/// - [fullscreen]: a read-only launcher field that opens fullscreen search UI.
enum PlacesAutocompleteFieldMode { inline, dialog, fullscreen }

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
    this.suggestionBuilder,
  });

  final PlacesClient client;
  final PlacesAutocompleteController? controller;
  final InputDecoration? decoration;
  final PlacesStrings strings;

  /// Preferred BCP-47 language code for results, such as `'en'` or `'he'`.
  final String? languageCode;

  /// Preferred CLDR region code for results, such as `'us'` or `'il'`.
  final String? regionCode;
  final LocationBias? locationBias;
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
  final String? selectionLanguageCode;
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
  final ValueChanged<PlaceSelection>? onSelection;
  final VoidCallback? onClearField;
  final ValueChanged<Object>? onError;
  final int maxSuggestions;
  final bool enabled;
  final bool autofocus;
  final bool showPoweredByGoogle;
  final Widget Function(BuildContext context, PlaceSuggestion suggestion)?
  suggestionBuilder;

  @override
  State<PlacesAutocompleteField> createState() =>
      _PlacesAutocompleteFieldState();
}

class _PlacesAutocompleteFieldState extends State<PlacesAutocompleteField> {
  PlacesAutocompleteController? _ownedController;
  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = const <PlaceSuggestion>[];
  Object? _error;
  bool _loading = false;
  bool _searchUiVisible = false;
  int _searchGeneration = 0;

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

  @override
  void initState() {
    super.initState();
    _controller.focusNode.addListener(_onFocusChanged);
    _syncFocusMode();
  }

  @override
  void didUpdateWidget(PlacesAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _ownedController)?.focusNode.removeListener(
        _onFocusChanged,
      );
      _controller.focusNode.addListener(_onFocusChanged);
    }
    _syncFocusMode();
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
    _controller.focusNode.removeListener(_onFocusChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_controller.focusNode.hasFocus || _isLauncherMode) {
      return;
    }
    _closeSearchUi();
  }

  void _onUserInputChanged(String value) {
    if (_isLauncherMode) {
      return;
    }
    _debounce?.cancel();
    final input = value.trim();
    if (input.isEmpty) {
      _closeSearchUi();
      return;
    }
    setState(() {
      _searchUiVisible = true;
      _loading = false;
      _error = null;
    });
    final generation = ++_searchGeneration;
    _debounce = Timer(_controller.debounceDuration, () {
      unawaited(_search(input, generation));
    });
  }

  void _invalidateSearches() {
    _searchGeneration++;
  }

  bool _isActiveSearch(String input, int generation) {
    return mounted &&
        generation == _searchGeneration &&
        _searchUiVisible &&
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
      _suggestions = const <PlaceSuggestion>[];
    });
  }

  Future<void> _search(String input, int generation) async {
    if (!_isActiveSearch(input, generation)) {
      return;
    }
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final suggestions = await widget.client.autocomplete(
        AutocompleteRequest(
          input: input,
          sessionToken: _controller.sessionToken,
          languageCode: widget.languageCode,
          regionCode: widget.regionCode,
          locationBias: widget.locationBias,
          locationRestriction: widget.locationRestriction,
          includedPrimaryTypes: widget.includedPrimaryTypes,
          includedRegionCodes: widget.includedRegionCodes,
          includePureServiceAreaBusinesses:
              widget.includePureServiceAreaBusinesses,
        ),
      );
      if (!_isActiveSearch(input, generation)) {
        return;
      }
      setState(() {
        _loading = false;
        _suggestions = suggestions.take(widget.maxSuggestions).toList();
      });
    } catch (error) {
      if (!_isActiveSearch(input, generation)) {
        return;
      }
      setState(() {
        _loading = false;
        _error = error;
        _suggestions = const <PlaceSuggestion>[];
      });
      widget.onError?.call(error);
    }
  }

  void _clearField() {
    _controller.clear();
    _closeSearchUi();
    widget.onClearField?.call();
  }

  Future<void> _handleSuggestionTap(PlaceSuggestion suggestion) async {
    _closeSearchUi();
    final initialSelection = PlaceSelection(suggestion: suggestion);
    _controller.setSelection(initialSelection);
    _controller.focusNode.unfocus();
    if (!_shouldResolvePlaceOnSelection) {
      widget.onSelection?.call(initialSelection);
      _controller.resetSession();
      return;
    }
    try {
      final place = await widget.client.fetchPlace(
        PlaceDetailsRequest(
          placeId: suggestion.placeId,
          fields: _effectiveSelectionFields,
          languageCode: widget.selectionLanguageCode ?? widget.languageCode,
          regionCode: widget.selectionRegionCode ?? widget.regionCode,
          sessionToken: _controller.sessionToken,
        ),
      );
      if (!mounted) {
        return;
      }
      PlaceTimeZoneData? timeZone;
      if (widget.fetchTimeZoneOnSelection) {
        timeZone = await widget.client.fetchTimeZoneForPlace(
          place,
          timestamp: widget.selectionTimeZoneAt,
          languageCode:
              widget.selectionTimeZoneLanguageCode ??
              widget.selectionLanguageCode ??
              widget.languageCode,
        );
      }
      final resolvedSelection = PlaceSelection(
        suggestion: suggestion,
        place: place,
        timeZone: timeZone,
      );
      _controller.setSelection(resolvedSelection, updateText: false);
      widget.onSelection?.call(resolvedSelection);
    } catch (error) {
      widget.onError?.call(error);
    } finally {
      _controller.resetSession();
    }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _controller.textController,
          focusNode: _controller.focusNode,
          canRequestFocus: !_isLauncherMode,
          enabled: widget.enabled,
          readOnly: _isLauncherMode,
          autofocus: widget.autofocus,
          onChanged: _onUserInputChanged,
          onTap: _isLauncherMode && widget.enabled ? _openOverlay : null,
          decoration: decoration,
        ),
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
            _InfoTile(child: Text(widget.strings.errorText))
          else if (_suggestions.isEmpty &&
              _controller.textController.text.trim().isNotEmpty)
            _InfoTile(child: Text(widget.strings.noResultsText))
          else if (_suggestions.isNotEmpty)
            Material(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: <Widget>[
                  for (final suggestion in _suggestions)
                    ListTile(
                      onTap: () => _handleSuggestionTap(suggestion),
                      title:
                          widget.suggestionBuilder?.call(context, suggestion) ??
                          Text(suggestion.primaryText.text),
                      subtitle: suggestion.secondaryText == null
                          ? null
                          : Text(suggestion.secondaryText!.text),
                      trailing: suggestion.distanceMeters == null
                          ? null
                          : Text('${suggestion.distanceMeters} m'),
                    ),
                  if (widget.showPoweredByGoogle)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: _PoweredByGoogleAttribution(),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  InputDecoration _buildDecoration() {
    final baseDecoration = widget.decoration ?? const InputDecoration();
    final clearButton = IconButton(
      onPressed: widget.enabled ? _clearField : null,
      icon: const Icon(Icons.clear),
      tooltip: widget.strings.clearLabel,
    );

    final userSuffix = baseDecoration.suffix;
    final userSuffixIcon = baseDecoration.suffixIcon;

    return baseDecoration.copyWith(
      hintText: baseDecoration.hintText ?? widget.strings.searchHint,
      suffix: _mergeSuffix(
        suffix: userSuffix,
        suffixIcon: userSuffixIcon,
        suffixIconConstraints: baseDecoration.suffixIconConstraints,
      ),
      suffixIcon: clearButton,
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
  const _PoweredByGoogleAttribution();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final assetName = brightness == Brightness.dark
        ? 'assets/google_white.png'
        : 'assets/google_black.png';
    return Image.asset(
      assetName,
      package: 'google_places_autocomplete',
      height: 18,
      semanticLabel: const PlacesStrings().poweredByGoogleLabel,
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
