part of 'places_autocomplete_field.dart';

/// What a [PlacesAutocompleteController] searches for and what a pick returns.
///
/// The autocomplete widgets take each of these as a parameter of the same
/// name; a controller used without a widget takes them here. See
/// [PlacesAutocompleteField] for what each one does.
@immutable
class PlacesAutocompleteOptions {
  /// Creates search and selection options. The defaults are the widgets'.
  const PlacesAutocompleteOptions({
    this.languageCode,
    this.regionCode,
    this.origin,
    this.locationBias,
    this.locationRestriction,
    this.includedPrimaryTypes = const <String>[],
    this.includedRegionCodes = const <String>[],
    this.includePureServiceAreaBusinesses = false,
    this.includeFutureOpeningBusinesses = false,
    this.includeQueryPredictions = false,
    this.maxSuggestions = 5,
    this.minInputLength = 1,
    this.fetchPlaceDetailsOnSelection = true,
    this.fetchTimeZoneOnSelection = false,
    this.selectionFields = PlaceFieldPresets.address,
    this.selectionLanguageCode,
    this.selectionRegionCode,
    this.selectionTimeZoneAt,
    this.selectionTimeZoneLanguageCode,
  }) : assert(minInputLength >= 1, 'minInputLength must be at least 1.');

  /// See [PlacesAutocompleteField.languageCode].
  final String? languageCode;

  /// See [PlacesAutocompleteField.regionCode].
  final String? regionCode;

  /// See [PlacesAutocompleteField.origin].
  final PlaceCoordinates? origin;

  /// See [PlacesAutocompleteField.locationBias].
  final LocationBias? locationBias;

  /// See [PlacesAutocompleteField.locationRestriction].
  final LocationRestriction? locationRestriction;

  /// See [PlacesAutocompleteField.includedPrimaryTypes].
  final List<String> includedPrimaryTypes;

  /// See [PlacesAutocompleteField.includedRegionCodes].
  final List<String> includedRegionCodes;

  /// See [PlacesAutocompleteField.includePureServiceAreaBusinesses].
  final bool includePureServiceAreaBusinesses;

  /// See [PlacesAutocompleteField.includeFutureOpeningBusinesses].
  final bool includeFutureOpeningBusinesses;

  /// See [PlacesAutocompleteField.includeQueryPredictions].
  final bool includeQueryPredictions;

  /// See [PlacesAutocompleteField.maxSuggestions].
  final int maxSuggestions;

  /// See [PlacesAutocompleteField.minInputLength].
  final int minInputLength;

  /// See [PlacesAutocompleteField.fetchPlaceDetailsOnSelection].
  final bool fetchPlaceDetailsOnSelection;

  /// See [PlacesAutocompleteField.fetchTimeZoneOnSelection].
  final bool fetchTimeZoneOnSelection;

  /// See [PlacesAutocompleteField.selectionFields].
  final Set<PlaceField> selectionFields;

  /// See [PlacesAutocompleteField.selectionLanguageCode].
  final String? selectionLanguageCode;

  /// See [PlacesAutocompleteField.selectionRegionCode].
  final String? selectionRegionCode;

  /// See [PlacesAutocompleteField.selectionTimeZoneAt].
  final DateTime? selectionTimeZoneAt;

  /// See [PlacesAutocompleteField.selectionTimeZoneLanguageCode].
  final String? selectionTimeZoneLanguageCode;

  // Whether the autocomplete requests would be the same. Only those settings
  // end a session when they change; the rest apply from the next search or
  // pick, so a widget rebuilt with, say, a fresh selectionTimeZoneAt keeps it.
  bool _sameSearch(PlacesAutocompleteOptions other) =>
      other.languageCode == languageCode &&
      other.regionCode == regionCode &&
      other.origin == origin &&
      other.locationBias == locationBias &&
      other.locationRestriction == locationRestriction &&
      listEquals(other.includedPrimaryTypes, includedPrimaryTypes) &&
      listEquals(other.includedRegionCodes, includedRegionCodes) &&
      other.includePureServiceAreaBusinesses ==
          includePureServiceAreaBusinesses &&
      other.includeFutureOpeningBusinesses == includeFutureOpeningBusinesses &&
      other.includeQueryPredictions == includeQueryPredictions;

  @override
  bool operator ==(Object other) =>
      other is PlacesAutocompleteOptions &&
      _sameSearch(other) &&
      other.maxSuggestions == maxSuggestions &&
      other.minInputLength == minInputLength &&
      other.fetchPlaceDetailsOnSelection == fetchPlaceDetailsOnSelection &&
      other.fetchTimeZoneOnSelection == fetchTimeZoneOnSelection &&
      setEquals(other.selectionFields, selectionFields) &&
      other.selectionLanguageCode == selectionLanguageCode &&
      other.selectionRegionCode == selectionRegionCode &&
      other.selectionTimeZoneAt == selectionTimeZoneAt &&
      other.selectionTimeZoneLanguageCode == selectionTimeZoneLanguageCode;

  @override
  int get hashCode => Object.hash(
    languageCode,
    regionCode,
    origin,
    locationBias,
    locationRestriction,
    Object.hashAll(includedPrimaryTypes),
    Object.hashAll(includedRegionCodes),
    includePureServiceAreaBusinesses,
    includeFutureOpeningBusinesses,
    includeQueryPredictions,
    maxSuggestions,
    minInputLength,
    fetchPlaceDetailsOnSelection,
    fetchTimeZoneOnSelection,
    Object.hashAllUnordered(selectionFields),
    selectionLanguageCode,
    selectionRegionCode,
    selectionTimeZoneAt,
    selectionTimeZoneLanguageCode,
  );
}

/// The state of a Places search — the text, focus, billing session,
/// suggestions, and selection — for [PlacesAutocompleteField] or for your own
/// search UI.
///
/// A widget creates one when you do not pass one. Pass your own to read or
/// drive the search from outside the widget, or use it with no widget at all:
///
/// ```dart
/// final controller = PlacesAutocompleteController(apiKey: 'YOUR_API_KEY');
///
/// TextField(
///   controller: controller.textController,
///   focusNode: controller.focusNode,
///   onChanged: (_) => controller.search(),
/// );
/// ListenableBuilder(
///   listenable: controller,
///   builder: (context, _) => Column(
///     children: [
///       for (final suggestion in controller.suggestions)
///         ListTile(
///           title: Text(suggestion.displayText),
///           onTap: () => controller.select(suggestion),
///         ),
///     ],
///   ),
/// );
/// ```
///
/// It notifies its listeners whenever its state changes.
///
/// **Billing sessions.** Every search in one session shares
/// [sessionToken]. [select] ends the session with the details request, as
/// Google prices it, and [clear] and [resetSession] end it without one. A
/// widget also ends it when the user leaves the field without picking; your
/// own UI does that by calling [resetSession]. [dispose] ends it too.
///
/// **Used by a widget**, the widget's own parameters and client apply, not
/// [options] or this controller's client, and its `debounceDuration`
/// overrides [debounceDuration] when set. They apply again once no widget
/// uses the controller. One widget uses it at a time.
class PlacesAutocompleteController extends ChangeNotifier {
  /// Creates a controller.
  ///
  /// To search without a widget, pass [apiKey], and the controller creates a
  /// [PlacesClient] and closes it in [dispose], or a [client] you own, which
  /// it never closes. A controller used only by a widget needs neither.
  ///
  /// Pass your own [textController] or [focusNode] to share them with the
  /// rest of your UI; the controller does not dispose them. [initialText]
  /// seeds the text controller the controller creates, so it cannot be
  /// combined with [textController].
  PlacesAutocompleteController({
    String initialText = '',
    this.debounceDuration = const Duration(milliseconds: 300),
    TextEditingController? textController,
    FocusNode? focusNode,
    PlacesClient? client,
    String? apiKey,
    this._options = const PlacesAutocompleteOptions(),
  }) : assert(
         client == null || apiKey == null,
         'Pass client or apiKey, not both.',
       ),
       assert(
         textController == null || initialText.isEmpty,
         'Set the text on your textController instead of initialText.',
       ),
       textController =
           textController ?? TextEditingController(text: initialText),
       _ownsTextController = textController == null,
       focusNode = focusNode ?? FocusNode(),
       _ownsFocusNode = focusNode == null,
       _ownClient =
           client ?? (apiKey == null ? null : PlacesClient(apiKey: apiKey)),
       _ownsClient = client == null && apiKey != null;

  /// The text being searched for.
  final TextEditingController textController;

  /// The search field's focus node.
  final FocusNode focusNode;

  /// How long the controller waits after the text changes before it
  /// searches.
  final Duration debounceDuration;

  final bool _ownsTextController;
  final bool _ownsFocusNode;
  final PlacesClient? _ownClient;
  final bool _ownsClient;
  PlacesAutocompleteOptions _options;
  bool _disposed = false;

  /// What the controller searches for and what a pick returns, when no
  /// widget uses it.
  ///
  /// Changing what it searches for — everything but the `maxSuggestions`,
  /// `minInputLength`, and selection settings, which apply from the next
  /// search or pick — ends the session.
  PlacesAutocompleteOptions get options => _options;
  set options(PlacesAutocompleteOptions value) {
    final sameSearch = value._sameSearch(_options);
    _options = value;
    if (_binding == null && !sameSearch) {
      resetSession();
    }
  }

  AutocompleteSessionToken _sessionToken = AutocompleteSessionToken.generate();
  PlaceSelection? _selection;

  /// Current autocomplete session token used to group search and selection.
  AutocompleteSessionToken get sessionToken => _sessionToken;

  /// The last selection, if any.
  PlaceSelection? get selectedSelection => _selection;

  /// The last selected suggestion, if any.
  PlaceSuggestion? get selectedSuggestion => _selection?.suggestion;

  /// The last resolved place details, if any.
  PlaceData? get selectedPlace => _selection?.place;

  /// The suggestions for the current text — at most
  /// [PlacesAutocompleteOptions.maxSuggestions] — or empty.
  List<AutocompleteSuggestion> get suggestions => _suggestions;

  /// What the search shows: loading, results, no results, or an error; `null`
  /// when no search is showing.
  PlacesSuggestionsStatus? get status {
    if (!_open) {
      return null;
    }
    if (_loading) {
      return PlacesSuggestionsStatus.loading;
    }
    if (_error != null) {
      return PlacesSuggestionsStatus.error;
    }
    if (_suggestions.isNotEmpty) {
      return PlacesSuggestionsStatus.results;
    }
    return textController.text.trim().isEmpty
        ? null
        : PlacesSuggestionsStatus.empty;
  }

  /// Why the last search failed, while [status] is
  /// [PlacesSuggestionsStatus.error].
  ///
  /// A failure that is not a [PlacesException] is wrapped in one of kind
  /// [PlacesErrorKind.unknown], with its type in `metadata`.
  PlacesException? get error => _error;

  /// The index in [suggestions] of the row highlighted from the keyboard, or
  /// `-1`. The first result is highlighted when results arrive.
  int get highlightIndex => _highlightIndex;

  /// Whether [select] is loading the picked place's details.
  bool get selectionLoading => _selectionLoading;

  /// Searches for the text in [textController], as typing in a widget does.
  ///
  /// Call it from your field's `onChanged`. It waits [debounceDuration]
  /// first, and a later call replaces an earlier one. Shorter text than
  /// [PlacesAutocompleteOptions.minInputLength] closes the results without
  /// ending the session; empty text ends it. It clears [selectedSelection],
  /// and abandons a pick whose details are still loading.
  ///
  /// Throws a [StateError] if neither the controller nor a widget using it
  /// has a client.
  void search() {
    _requireClient();
    _userInputChanged(textController.text);
  }

  /// Searches again for the current text, at once — after an error, for
  /// example. It does nothing for text shorter than
  /// [PlacesAutocompleteOptions.minInputLength], or while a pick is loading.
  void retry() {
    _requireClient();
    _retrySearch();
  }

  /// Picks [suggestion].
  ///
  /// For a [PlaceSuggestion] it sets [selectedSelection] and the text, loads
  /// the place's details and time zone as [options] ask, and ends the
  /// session with the details request. It completes with the selection, or
  /// `null` if the pick was abandoned — by a new search, [clear],
  /// [resetSession], or [dispose] — before it finished, and with the error if
  /// a request failed.
  ///
  /// While another pick is still loading it does nothing and completes with
  /// `null`.
  ///
  /// For a [QuerySuggestion] it puts the suggested text in [textController],
  /// closes the results, ends the session, and completes with `null`; call
  /// [search] to search for that text. A widget using the controller does
  /// that itself when its `searchOnQuerySelection` is `true`.
  ///
  /// Throws a [StateError] if neither the controller nor a widget using it
  /// has a client.
  Future<PlaceSelection?> select(AutocompleteSuggestion suggestion) {
    _requireClient();
    return _select(suggestion, rethrowErrors: true);
  }

  /// Moves the keyboard highlight [delta] rows down — up when negative —
  /// wrapping at either end.
  void moveHighlight(int delta) {
    if (_suggestions.isEmpty) {
      return;
    }
    _highlightIndex = (_highlightIndex + delta) % _suggestions.length;
    _changed();
  }

  /// Clears the selection and the text, and ends the session.
  void clear() {
    _selection = null;
    textController.clear();
    resetSession(notify: false);
    notifyListeners();
  }

  /// Clears only the selected value while preserving the current input text.
  void clearSelection() {
    if (_selection == null) {
      return;
    }
    _selection = null;
    notifyListeners();
  }

  /// Ends the session and starts a new one: cancels any search or pick in
  /// progress and closes the results.
  ///
  /// Call it when the user leaves your search UI without picking a place.
  void resetSession({bool notify = true}) {
    final previous = _sessionToken;
    _sessionToken = AutocompleteSessionToken.generate();
    _endSession(previous);
    _invalidateAsyncWork(notify: false);
    if (notify) {
      notifyListeners();
    }
  }

  /// Updates the controller with a new [selection].
  void setSelection(PlaceSelection selection, {bool updateText = true}) {
    _selection = selection;
    if (updateText) {
      textController
        ..text = selection.displayText
        ..selection = TextSelection.collapsed(
          offset: selection.displayText.length,
        );
    }
    notifyListeners();
  }

  /// Restores [selection] without beginning a new user selection flow.
  ///
  /// Form wrappers use this to synchronize initial and reset values. Passing
  /// `null` clears both the selected value and visible text.
  void restoreSelection(PlaceSelection? selection) {
    final text = selection?.displayText ?? '';
    final selectionChanged = !identical(_selection, selection);
    final textChanged = textController.text != text;
    if (!selectionChanged && !textChanged) {
      return;
    }

    _selection = selection;
    if (textChanged) {
      textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    notifyListeners();
  }

  /// Ends the session, cancels any work in progress, and releases what the
  /// controller created: its text controller, focus node, and client.
  @override
  void dispose() {
    _disposed = true;
    if (_binding == null) {
      _endSession(_sessionToken);
    }
    _invalidateAsyncWork(notify: false);
    if (_ownsTextController) {
      textController.dispose();
    }
    if (_ownsFocusNode) {
      focusNode.dispose();
    }
    if (_ownsClient) {
      unawaited(_ownClient!.close());
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // The search engine. A widget drives it through _binding; its state is what
  // the widget draws.

  _PlacesAutocompleteFieldState? _binding;
  Timer? _debounce;
  List<AutocompleteSuggestion> _suggestions = const <AutocompleteSuggestion>[];
  PlacesException? _error;
  bool _loading = false;
  bool _selectionLoading = false;
  bool _open = false;
  int _highlightIndex = -1;
  int _searchGeneration = 0;
  PlacesCancellationToken? _searchCancellationToken;
  // The pick in progress, if any; a pick is current while its token is.
  PlacesCancellationToken? _selectionCancellationToken;
  // The session the last request went out in. Compared by value with the
  // current one, so it needs no clearing when the session resets.
  AutocompleteSessionToken? _searchedSessionToken;

  // A widget's parameters and client win while it uses the controller.
  PlacesClient? get _client => _binding?._client ?? _ownClient;

  PlacesAutocompleteOptions get _effectiveOptions =>
      _binding?._options ?? _options;

  Duration get _debounceDuration =>
      _binding?.widget.debounceDuration ?? debounceDuration;

  bool get _selectionInProgress => _selectionCancellationToken != null;

  // Shown, pending, or already billed: input below minInputLength closes the
  // results but not the session its earlier requests went out in.
  bool get _hasActiveSession =>
      _open ||
      _loading ||
      _suggestions.isNotEmpty ||
      _searchedSessionToken?.value == _sessionToken.value;

  void _requireClient() {
    if (_client == null) {
      throw StateError(
        'This PlacesAutocompleteController has no client. Pass apiKey or '
        'client to it, or use it with a Places widget.',
      );
    }
  }

  void _changed({bool notify = true}) {
    if (notify && !_disposed) {
      notifyListeners();
    }
  }

  // The newest widget wins. Moving a controller to another widget builds the
  // new one before the old one is disposed, so for that frame both hold it:
  // the old one's search and pick end here, with its session, and its later
  // detach has nothing left to do. Called while the new widget builds.
  void _attach(_PlacesAutocompleteFieldState binding) {
    final previous = _binding;
    if (previous != null && !identical(previous, binding)) {
      _endWidgetSession(previous._client);
    }
    _binding = binding;
  }

  // The widget stopped using the controller. Its client is passed in, since
  // the widget may already have switched to another. Called while the tree is
  // torn down.
  void _detach(_PlacesAutocompleteFieldState binding, PlacesClient client) {
    if (!identical(binding, _binding)) {
      return;
    }
    _endWidgetSession(client);
    _binding = null;
  }

  // The widget's client or search configuration changed. Called while the
  // widget rebuilds.
  void _configurationChanged(PlacesClient previousClient) {
    _endWidgetSession(previousClient);
  }

  // Ends the session on [client], starts a new one, and stops all work — from
  // a widget's lifecycle, where listeners cannot be told until the frame ends.
  void _endWidgetSession(PlacesClient client) {
    final showedAnything = _showsAnything;
    unawaited(client.endAutocompleteSession(_sessionToken));
    _sessionToken = AutocompleteSessionToken.generate();
    _invalidateAsyncWork(notify: false);
    _notifyAfterFrame(showedAnything);
  }

  // A launcher closes any search when it builds.
  void _closeSearchWhileBuilding() {
    final showedAnything = _showsAnything;
    _closeSearch(notify: false);
    _notifyAfterFrame(showedAnything);
  }

  // From a widget's lifecycle: listeners hear of it once the frame is built,
  // and only if something they could be showing changed — so a parent that
  // rebuilds on this controller cannot rebuild itself in a loop.
  void _notifyAfterFrame(bool changed) {
    if (!changed || _disposed) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  bool get _showsAnything =>
      _open ||
      _loading ||
      _selectionLoading ||
      _error != null ||
      _suggestions.isNotEmpty;

  void _endSession(AutocompleteSessionToken token) {
    final client = _client;
    if (client != null) {
      unawaited(client.endAutocompleteSession(token));
    }
  }

  // Closes the search and abandons any pick in progress.
  void _invalidateAsyncWork({bool notify = true}) {
    _closeSearch(notify: false);
    _selectionCancellationToken?.cancel();
    _selectionCancellationToken = null;
    _selectionLoading = false;
    _changed(notify: notify);
  }

  // The user left the search without picking: close it, and end the session
  // if anything went out in it.
  void _abandonSearch() {
    final hadActiveSession = _hasActiveSession;
    _closeSearch();
    if (hadActiveSession) {
      resetSession();
    }
  }

  // The text changed.
  void _userInputChanged(String value) {
    if (_selectionInProgress) {
      // Typing over a pick whose details are still loading abandons it: they
      // would arrive for text the user has replaced. A new session also
      // cancels the details request.
      resetSession();
    }
    if (_selection != null) {
      clearSelection();
      _binding?.widget.onClearField?.call();
    }
    _debounce?.cancel();
    final input = value.trim();
    if (input.isEmpty) {
      _abandonSearch();
      return;
    }
    if (input.characters.length < _effectiveOptions.minInputLength) {
      // Still the same search, so the session carries on.
      _closeSearch();
      return;
    }
    _open = true;
    // With nothing on screen yet, the pending search shows as loading — not
    // as an empty result before any request has been sent.
    _loading = _suggestions.isEmpty;
    _error = null;
    _highlightIndex = -1;
    _changed();
    final generation = ++_searchGeneration;
    _debounce = Timer(_debounceDuration, () {
      unawaited(_search(input, generation));
    });
  }

  bool _isActiveSearch(String input, int generation) {
    return generation == _searchGeneration &&
        _open &&
        (_binding?._canShowResults ?? !_disposed) &&
        textController.text.trim() == input;
  }

  void _closeSearch({bool notify = true}) {
    _debounce?.cancel();
    _searchCancellationToken?.cancel();
    _searchCancellationToken = null;
    _searchGeneration++;
    _open = false;
    _loading = false;
    _error = null;
    _suggestions = const <AutocompleteSuggestion>[];
    _highlightIndex = -1;
    _changed(notify: notify);
  }

  // A search that can no longer show its result. If it was the latest, nothing
  // will replace its loading state, so close the search rather than spin.
  void _dropSearch(int generation) {
    if (generation == _searchGeneration) {
      _closeSearch();
    }
  }

  Future<void> _search(String input, int generation) async {
    if (!_isActiveSearch(input, generation)) {
      _dropSearch(generation);
      return;
    }
    _searchCancellationToken?.cancel();
    final cancellationToken = PlacesCancellationToken();
    _searchCancellationToken = cancellationToken;
    final options = _effectiveOptions;
    final onError = _binding?.widget.onError;
    final client = _client!;
    try {
      _loading = true;
      _error = null;
      // The rows for the previous text: hidden behind the loading state, so
      // the keyboard must not be able to pick them.
      _suggestions = const <AutocompleteSuggestion>[];
      _highlightIndex = -1;
      _changed();
      final request = AutocompleteRequest(
        input: input,
        inputOffset: _unicodeInputOffset(input),
        sessionToken: _sessionToken,
        languageCode: options.languageCode,
        regionCode: options.regionCode,
        origin: options.origin,
        locationBias: options.locationBias,
        locationRestriction: options.locationRestriction,
        includedPrimaryTypes: options.includedPrimaryTypes,
        includedRegionCodes: options.includedRegionCodes,
        includePureServiceAreaBusinesses:
            options.includePureServiceAreaBusinesses,
        includeFutureOpeningBusinesses: options.includeFutureOpeningBusinesses,
        includeQueryPredictions: options.includeQueryPredictions,
      );
      _searchedSessionToken = request.sessionToken;
      final suggestions = options.includeQueryPredictions
          ? await client.autocompleteSuggestions(
              request,
              cancellationToken: cancellationToken,
            )
          : await client.autocomplete(
              request,
              cancellationToken: cancellationToken,
            );
      if (!_isActiveSearch(input, generation)) {
        _dropSearch(generation);
        return;
      }
      final limitedSuggestions = suggestions
          .take(options.maxSuggestions.clamp(1, 5))
          .toList(growable: false);
      _loading = false;
      _suggestions = limitedSuggestions;
      _highlightIndex = limitedSuggestions.isEmpty ? -1 : 0;
      _changed();
    } catch (error) {
      if (!_isActiveSearch(input, generation)) {
        _dropSearch(generation);
        return;
      }
      _loading = false;
      // The client only throws PlacesException; anything else is wrapped so
      // the view always gets the typed error.
      _error = error is PlacesException
          ? error
          : PlacesException(
              'The autocomplete request failed.',
              operation: PlacesOperation.autocomplete,
              metadata: <String, Object?>{
                'errorType': error.runtimeType.toString(),
              },
            );
      _suggestions = const <AutocompleteSuggestion>[];
      _highlightIndex = -1;
      _changed();
      onError?.call(error);
    } finally {
      if (identical(_searchCancellationToken, cancellationToken)) {
        _searchCancellationToken = null;
      }
    }
  }

  void _retrySearch() {
    final input = textController.text.trim();
    if (input.isEmpty ||
        input.characters.length < _effectiveOptions.minInputLength ||
        _selectionInProgress ||
        _disposed) {
      return;
    }
    _debounce?.cancel();
    _open = true;
    _loading = true;
    _error = null;
    _highlightIndex = -1;
    _changed();
    final generation = ++_searchGeneration;
    if (_binding == null || focusNode.hasFocus) {
      unawaited(_search(input, generation));
      return;
    }
    // The retry control itself takes focus on some platforms, notably web.
    // A widget only shows results while its field is focused — that check is
    // what rejects stale ones — so restore focus and search once it settles.
    // Reusing _debounce keeps this cancellable by disposal and by every other
    // path that invalidates pending work.
    focusNode.requestFocus();
    _debounce = Timer(Duration.zero, () {
      unawaited(_search(input, generation));
    });
  }

  int? _unicodeInputOffset(String input) {
    final rawInput = textController.text;
    final selectionOffset = textController.selection.extentOffset;
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

  Future<PlaceSelection?> _select(
    AutocompleteSuggestion suggestion, {
    bool rethrowErrors = false,
  }) async {
    if (_selectionInProgress) {
      return null;
    }
    final binding = _binding;
    final widget = binding?.widget;
    if (suggestion is QuerySuggestion) {
      _closeSearch();
      textController
        ..text = suggestion.displayText
        ..selection = TextSelection.collapsed(
          offset: suggestion.displayText.length,
        );
      resetSession();
      widget?.onQuerySelection?.call(suggestion);
      if (widget?.searchOnQuerySelection ?? false) {
        _retrySearch();
      }
      return null;
    }
    if (suggestion is! PlaceSuggestion) {
      return null;
    }
    final options = _effectiveOptions;
    final client = _client!;
    final sessionToken = _sessionToken;
    final cancellationToken = PlacesCancellationToken();
    _selectionCancellationToken = cancellationToken;
    _closeSearch();
    final initialSelection = PlaceSelection(
      suggestion: suggestion,
      sessionToken: sessionToken,
    );
    setSelection(initialSelection);
    if (widget?.unfocusOnSelection ?? false) {
      focusNode.unfocus();
    }
    try {
      if (!options.fetchPlaceDetailsOnSelection &&
          !options.fetchTimeZoneOnSelection) {
        if (!_isActiveSelection(cancellationToken, client, binding)) {
          return null;
        }
        widget?.onSelection?.call(initialSelection);
        return initialSelection;
      }
      _selectionLoading = true;
      _changed();
      final place = await client.fetchPlace(
        PlaceDetailsRequest(
          placeId: suggestion.placeId,
          fields: options.fetchTimeZoneOnSelection
              ? <PlaceField>{...options.selectionFields, PlaceField.location}
              : options.selectionFields,
          languageCode: options.selectionLanguageCode ?? options.languageCode,
          regionCode: options.selectionRegionCode ?? options.regionCode,
          sessionToken: sessionToken,
        ),
        cancellationToken: cancellationToken,
      );
      if (!_isActiveSelection(cancellationToken, client, binding)) {
        return null;
      }
      PlaceTimeZoneData? timeZone;
      if (options.fetchTimeZoneOnSelection) {
        timeZone = await client.fetchTimeZoneForPlace(
          place,
          timestamp: options.selectionTimeZoneAt,
          languageCode:
              options.selectionTimeZoneLanguageCode ??
              options.selectionLanguageCode ??
              options.languageCode,
          cancellationToken: cancellationToken,
        );
        if (!_isActiveSelection(cancellationToken, client, binding)) {
          return null;
        }
      }
      final resolvedSelection = PlaceSelection(
        suggestion: suggestion,
        sessionToken: sessionToken,
        place: place,
        timeZone: timeZone,
      );
      setSelection(resolvedSelection, updateText: false);
      widget?.onSelection?.call(resolvedSelection);
      return resolvedSelection;
    } catch (error) {
      if (!_isActiveSelection(cancellationToken, client, binding)) {
        return null;
      }
      widget?.onError?.call(error);
      if (rethrowErrors) {
        rethrow;
      }
      return null;
    } finally {
      if (_isActiveSelection(cancellationToken, client, binding)) {
        _selectionCancellationToken = null;
        _selectionLoading = false;
        _changed();
      }
      // Whatever moved the session on — a reset, a widget change, a new
      // client — has already ended it.
      if (!_disposed &&
          _sessionToken.value == sessionToken.value &&
          identical(binding, _binding) &&
          identical(client, _client)) {
        resetSession();
      }
    }
  }

  bool _isActiveSelection(
    PlacesCancellationToken cancellationToken,
    PlacesClient client,
    _PlacesAutocompleteFieldState? binding,
  ) {
    return !_disposed &&
        identical(cancellationToken, _selectionCancellationToken) &&
        identical(binding, _binding) &&
        identical(client, _client);
  }
}
