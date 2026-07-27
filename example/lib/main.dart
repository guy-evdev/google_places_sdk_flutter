import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
const _proxyPlacesUrl = String.fromEnvironment('PLACES_PROXY_URL');
const _proxyTimeZoneUrl = String.fromEnvironment('PLACES_PROXY_TIME_ZONE_URL');
const _proxyAccessToken = String.fromEnvironment('PLACES_PROXY_ACCESS_TOKEN');

bool get _hasClientConfiguration =>
    _apiKey.isNotEmpty || _proxyPlacesUrl.isNotEmpty;

PlacesClient _createPlacesClient() {
  if (_proxyPlacesUrl.isNotEmpty) {
    return PlacesClient.proxy(
      placesEndpoint: Uri.parse(_proxyPlacesUrl),
      timeZoneEndpoint: _proxyTimeZoneUrl.isEmpty
          ? null
          : Uri.parse(_proxyTimeZoneUrl),
      authentication: _proxyAccessToken.isEmpty
          ? null
          : (_) => <String, String>{
              'Authorization': 'Bearer $_proxyAccessToken',
            },
    );
  }
  return PlacesClient(
    apiKey: _apiKey,
    options: const PlacesClientOptions(requestTimeout: Duration(seconds: 15)),
  );
}

const _exampleDetailsFields = <PlaceField>{
  ...PlaceFieldPresets.rich,
  PlaceField.googleMapsTypeLabel,
  PlaceField.openingDate,
  PlaceField.googleMapsLinks,
  PlaceField.priceRange,
  PlaceField.plusCode,
  PlaceField.attributions,
  PlaceField.timeZone,
  PlaceField.transitStation,
};

void main() {
  runApp(const ExampleApp());
}

enum WidgetType { textField, formField, dialog, fullscreen }

extension on WidgetType {
  String get label => switch (this) {
    WidgetType.textField => 'Text Field',
    WidgetType.formField => 'Form',
    WidgetType.dialog => 'Dialog',
    WidgetType.fullscreen => 'Fullscreen',
  };
}

enum TextSearchMode { singlePage, paged }

extension on TextSearchMode {
  String get label => switch (this) {
    TextSearchMode.singlePage => 'Single page',
    TextSearchMode.paged => 'Paged',
  };
}

enum DemoLocale {
  english(Locale('en', 'US'), false),
  hebrew(Locale('he', 'IL'), true),
  arabic(Locale('ar', 'SA'), true);

  const DemoLocale(this.locale, this.isRtl);

  final Locale locale;
  final bool isRtl;

  String get label => switch (this) {
    DemoLocale.english => 'English',
    DemoLocale.hebrew => 'עברית',
    DemoLocale.arabic => 'العربية',
  };
}

class DemoConfiguration {
  const DemoConfiguration({
    this.locale = DemoLocale.english,
    this.widgetType = WidgetType.textField,
    this.textSearchMode = TextSearchMode.singlePage,
    this.fetchPlaceDetails = true,
    this.fetchTimeZone = false,
    this.includeQueryPredictions = false,
    this.showDistanceFromOrigin = false,
    this.pageSize = 5,
  });

  /// Fixed origin used by the distance demo, so the sample needs no location
  /// permission. Real apps would pass the device's current coordinates.
  static const demoOrigin = PlaceCoordinates(
    latitude: 40.7580,
    longitude: -73.9855,
  );

  final DemoLocale locale;
  final WidgetType widgetType;
  final TextSearchMode textSearchMode;
  final bool fetchPlaceDetails;
  final bool fetchTimeZone;
  final bool includeQueryPredictions;
  final bool showDistanceFromOrigin;
  final int pageSize;

  /// Origin handed to the autocomplete widgets, or `null` when the demo is
  /// not asking Google for distances.
  PlaceCoordinates? get origin => showDistanceFromOrigin ? demoOrigin : null;

  DemoConfiguration copyWith({
    DemoLocale? locale,
    WidgetType? widgetType,
    TextSearchMode? textSearchMode,
    bool? fetchPlaceDetails,
    bool? fetchTimeZone,
    bool? includeQueryPredictions,
    bool? showDistanceFromOrigin,
    int? pageSize,
  }) {
    return DemoConfiguration(
      locale: locale ?? this.locale,
      widgetType: widgetType ?? this.widgetType,
      textSearchMode: textSearchMode ?? this.textSearchMode,
      fetchPlaceDetails: fetchPlaceDetails ?? this.fetchPlaceDetails,
      fetchTimeZone: fetchTimeZone ?? this.fetchTimeZone,
      includeQueryPredictions:
          includeQueryPredictions ?? this.includeQueryPredictions,
      showDistanceFromOrigin:
          showDistanceFromOrigin ?? this.showDistanceFromOrigin,
      pageSize: pageSize ?? this.pageSize,
    );
  }
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key, this.client});

  /// Optional caller-owned client, primarily useful for example widget tests.
  final PlacesClient? client;

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  late final PlacesClient _client;
  late final bool _ownsClient;
  final PlacesAutocompleteController _controller =
      PlacesAutocompleteController();
  final TextEditingController _textSearchController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  DemoConfiguration _configuration = const DemoConfiguration();
  PlacesAutocompleteFieldMode _fieldMode = PlacesAutocompleteFieldMode.inline;
  PlaceSelection? _selection;
  Object? _autocompleteError;
  Object? _textSearchError;
  String? _textSearchValidationError;
  final List<PlaceData> _textSearchResults = <PlaceData>[];
  String? _nextPageToken;
  String? _searchUri;
  int _loadedTextSearchPages = 0;
  bool _isLoadingTextSearch = false;
  PlacesCancellationToken? _textSearchCancellation;
  int _textSearchGeneration = 0;

  DemoLocale get _demoLocale => _configuration.locale;

  WidgetType get _widgetType => _configuration.widgetType;

  bool get _fetchPlaceDetails => _configuration.fetchPlaceDetails;

  bool get _fetchTimeZoneOnSelection => _configuration.fetchTimeZone;

  bool get _includeQueryPredictions => _configuration.includeQueryPredictions;

  PlaceCoordinates? get _origin => _configuration.origin;

  /// Decoration shared by every widget mode, so the demo shows that dialog and
  /// fullscreen launchers honour field customization too.
  InputDecoration get _fieldDecoration => const InputDecoration(
    labelText: 'Address',
    prefixIcon: Icon(Icons.place_outlined),
    border: OutlineInputBorder(),
  );

  @override
  void initState() {
    super.initState();
    _ownsClient = widget.client == null;
    _client = widget.client ?? _createPlacesClient();
  }

  @override
  void dispose() {
    _cancelTextSearch();
    _controller.dispose();
    _textSearchController.dispose();
    if (_ownsClient) {
      _client.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'google_places_sdk_flutter example',
      debugShowCheckedModeBanner: false,
      locale: _demoLocale.locale,
      supportedLocales: DemoLocale.values
          .map((locale) => locale.locale)
          .toList(),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: _demoLocale.isRtl
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: child!,
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B5D3B)),
        useMaterial3: true,
      ),
      home: Builder(
        builder: (appContext) => Scaffold(
          appBar: AppBar(title: const Text('google_places_sdk_flutter')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: widget.client == null && !_hasClientConfiguration
                ? const _MissingConfigurationNotice()
                : _buildContent(appContext),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final strings = _stringsFor(_demoLocale);

    return ListView(
      children: <Widget>[
        _ConfigurationSummary(
          configuration: _configuration,
          onOpen: () => _openConfiguration(context),
        ),
        const SizedBox(height: 24),
        Text(
          'Autocomplete widget',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        if (_widgetType == WidgetType.textField) ...[
          const Text('Text Field Type', textAlign: TextAlign.center),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              SegmentedButton<PlacesAutocompleteFieldMode>(
                segments: const <ButtonSegment<PlacesAutocompleteFieldMode>>[
                  ButtonSegment<PlacesAutocompleteFieldMode>(
                    value: PlacesAutocompleteFieldMode.inline,
                    label: Text('Inline'),
                  ),
                  ButtonSegment<PlacesAutocompleteFieldMode>(
                    value: PlacesAutocompleteFieldMode.dialog,
                    label: Text('Dialog'),
                  ),
                  ButtonSegment<PlacesAutocompleteFieldMode>(
                    value: PlacesAutocompleteFieldMode.fullscreen,
                    label: Text('Fullscreen'),
                  ),
                ],
                selected: <PlacesAutocompleteFieldMode>{_fieldMode},
                onSelectionChanged: (selection) {
                  setState(() {
                    _fieldMode = selection.first;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          PlacesAutocompleteField(
            client: _client,
            controller: _controller,
            decoration: _fieldDecoration,
            strings: strings,
            languageCode: _demoLocale.locale.languageCode,
            regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
            origin: _origin,
            fetchPlaceDetailsOnSelection: _fetchPlaceDetails,
            fetchTimeZoneOnSelection: _fetchTimeZoneOnSelection,
            selectionFields: _exampleDetailsFields,
            fieldMode: _fieldMode,
            includeQueryPredictions: _includeQueryPredictions,
            onSelection: (selection) {
              setState(() {
                _selection = selection;
                _autocompleteError = null;
              });
            },
            onQuerySelection: (selection) {
              setState(() {
                _selection = null;
                _autocompleteError = null;
              });
              debugPrint('Query suggestion: ${selection.displayText}');
            },
            onClearField: () {
              setState(() {
                _selection = null;
                _autocompleteError = null;
              });
            },
            onError: (error) {
              setState(() {
                _autocompleteError = error;
                debugPrint(error.toString());
              });
            },
          ),
          const SizedBox(height: 24),
        ],
        if (_widgetType == WidgetType.formField) ...<Widget>[
          const Text('FormField and reset', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: PlacesAutocompleteFormField(
              client: _client,
              controller: _controller,
              decoration: _fieldDecoration,
              strings: strings,
              languageCode: _demoLocale.locale.languageCode,
              regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
              origin: _origin,
              fetchPlaceDetailsOnSelection: _fetchPlaceDetails,
              fetchTimeZoneOnSelection: _fetchTimeZoneOnSelection,
              selectionFields: _exampleDetailsFields,
              includeQueryPredictions: _includeQueryPredictions,
              validator: (selection) => selection == null
                  ? 'Choose a place before submitting.'
                  : null,
              onSelection: (selection) {
                setState(() {
                  _selection = selection;
                  _autocompleteError = null;
                });
              },
              onClearField: () {
                setState(() {
                  _selection = null;
                  _autocompleteError = null;
                });
              },
              onReset: () {
                setState(() {
                  _selection = null;
                  _autocompleteError = null;
                });
              },
              onError: (error) {
                setState(() {
                  _autocompleteError = error;
                });
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            alignment: WrapAlignment.center,
            children: <Widget>[
              FilledButton(
                onPressed: () => _formKey.currentState?.validate(),
                child: const Text('Validate form'),
              ),
              OutlinedButton(
                onPressed: () => _formKey.currentState?.reset(),
                child: const Text('Reset form'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (_widgetType == WidgetType.dialog ||
            _widgetType == WidgetType.fullscreen) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: <Widget>[
              FilledButton.tonal(
                onPressed: () => _openOverlay(
                  context,
                  strings,
                  mode: _widgetType == WidgetType.fullscreen
                      ? PlacesAutocompleteOverlayMode.fullscreen
                      : PlacesAutocompleteOverlayMode.dialog,
                ),
                child: const Text('Click to Search'),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
        if (_selection != null)
          Card(
            child: ListTile(
              title: Text(_selection!.suggestion.primaryText.text),
              subtitle: Text(
                '${_selection!.displayText}\n'
                'Autocomplete billing session preserved: '
                '${_selection!.sessionToken == null ? 'no' : 'yes'}',
              ),
              isThreeLine: true,
            ),
          ),
        if (_selection?.place != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (_selection!.place!.route != null ||
                      _selection!.place!.streetNumber != null ||
                      _selection!.place!.locality != null ||
                      _selection!.place!.administrativeArea != null ||
                      _selection!.place!.postalCode != null ||
                      _selection!.place!.country != null) ...<Widget>[
                    Text(
                      'Typed address fields',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_selection!.place!.route != null)
                      Text('route: ${_selection!.place!.route}'),
                    if (_selection!.place!.streetNumber != null)
                      Text('streetNumber: ${_selection!.place!.streetNumber}'),
                    if (_selection!.place!.locality != null)
                      Text('locality: ${_selection!.place!.locality}'),
                    if (_selection!.place!.administrativeArea != null)
                      Text(
                        'administrativeArea: ${_selection!.place!.administrativeArea}',
                      ),
                    if (_selection!.place!.postalCode != null)
                      Text('postalCode: ${_selection!.place!.postalCode}'),
                    if (_selection!.place!.country != null)
                      Text('country: ${_selection!.place!.country}'),
                    if (_selection!.place!.countryCode != null)
                      Text('countryCode: ${_selection!.place!.countryCode}'),
                    const SizedBox(height: 16),
                  ],
                  if (_selection!.place!.googleMapsTypeLabel != null ||
                      _selection!.place!.openingDate != null ||
                      _selection!.place!.priceRange != null ||
                      _selection!.place!.timeZone != null ||
                      _selection!.place!.transitStation != null) ...<Widget>[
                    Text(
                      'Current Place resource fields',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_selection!.place!.googleMapsTypeLabel != null)
                      Text(
                        'typeLabel: '
                        '${_selection!.place!.googleMapsTypeLabel!.text}',
                      ),
                    if (_selection!.place!.openingDate != null)
                      Text(
                        'openingDate: '
                        '${_selection!.place!.openingDate!.year}-'
                        '${_selection!.place!.openingDate!.month}-'
                        '${_selection!.place!.openingDate!.day}',
                      ),
                    if (_selection!.place!.priceRange?.startPrice != null)
                      Text(
                        'priceFrom: '
                        '${_selection!.place!.priceRange!.startPrice!.currencyCode} '
                        '${_selection!.place!.priceRange!.startPrice!.units}',
                      ),
                    if (_selection!.place!.timeZone != null)
                      Text('placeTimeZone: ${_selection!.place!.timeZone!.id}'),
                    if (_selection!.place!.transitStation != null)
                      Text(
                        'transitStation: '
                        '${_selection!.place!.transitStation!.displayName?.text ?? 'available'}',
                      ),
                    if (_selection!.place!.googleMapsLinks?.placeUri != null)
                      SelectableText(
                        'Google Maps: '
                        '${_selection!.place!.googleMapsLinks!.placeUri}',
                      ),
                    if (_selection!.place!.attributions.isNotEmpty)
                      Text(
                        'Attribution: '
                        '${_selection!.place!.attributions.map((item) => item.provider).join(', ')}',
                      ),
                    const SizedBox(height: 16),
                  ],
                  SelectableText(prettyJson(_selection!.place!.rawData)),
                ],
              ),
            ),
          ),
        if (_selection?.timeZone != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SelectableText(prettyJson(_selection!.timeZone!.rawData)),
            ),
          ),
        if (_autocompleteError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_safeErrorText(_autocompleteError!)),
            ),
          ),
        const Divider(height: 40),
        _buildTextSearchSection(context),
      ],
    );
  }

  String _safeErrorText(Object error) {
    if (error case final PlacesException placesError) {
      final operation = placesError.operation?.name ?? 'unknown operation';
      final code = placesError.code == null ? '' : ' · ${placesError.code}';
      final retry = placesError.retryable ? ' · retryable' : '';
      return '${placesError.kind.name} · $operation$code$retry\n'
          '${placesError.message}';
    }
    return 'Unexpected error. See the debug console for development details.';
  }

  Future<void> _openOverlay(
    BuildContext context,
    PlacesStrings strings, {
    PlacesAutocompleteOverlayMode mode = PlacesAutocompleteOverlayMode.dialog,
  }) async {
    final selection = await PlacesAutocompleteOverlay.show(
      context,
      client: _client,
      mode: mode,
      decoration: _fieldDecoration,
      strings: strings,
      languageCode: _demoLocale.locale.languageCode,
      regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
      origin: _origin,
      fetchPlaceDetailsOnSelection: _fetchPlaceDetails,
      fetchTimeZoneOnSelection: _fetchTimeZoneOnSelection,
      selectionFields: mode == PlacesAutocompleteOverlayMode.dialog
          ? PlaceFieldPresets.recommended
          : PlaceFieldPresets.minimal,
      includeQueryPredictions: _includeQueryPredictions,
      onQuerySelection: (selection) {
        setState(() {
          _selection = null;
          _autocompleteError = null;
        });
        debugPrint('Query suggestion: ${selection.displayText}');
      },
      onError: (error) {
        setState(() {
          _autocompleteError = error;
          debugPrint(error.toString());
        });
      },
    );

    if (selection == null) {
      return;
    }

    setState(() {
      _selection = selection;
      _autocompleteError = null;
    });
  }

  Widget _buildTextSearchSection(BuildContext context) {
    final isPaged = _configuration.textSearchMode == TextSearchMode.paged;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Text Search', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          isPaged
              ? 'Search with pagination metadata and load additional pages.'
              : 'Search once and receive a simple list of places.',
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey<String>('text-search-input'),
          controller: _textSearchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Text Search query',
            hintText: 'For example: Coffee near Times Square',
            border: const OutlineInputBorder(),
            errorText: _textSearchValidationError,
            suffixIcon: _textSearchController.text.isEmpty
                ? null
                : IconButton(
                    key: const ValueKey<String>('text-search-clear'),
                    tooltip: 'Clear Text Search',
                    onPressed: _clearTextSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (_) {
            setState(() {
              _textSearchValidationError = null;
            });
          },
          onSubmitted: (_) => _runTextSearch(),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: <Widget>[
            FilledButton.icon(
              key: const ValueKey<String>('text-search-submit'),
              onPressed: _isLoadingTextSearch ? null : _runTextSearch,
              icon: const Icon(Icons.search),
              label: const Text('Search'),
            ),
            if (isPaged && _nextPageToken != null)
              OutlinedButton.icon(
                key: const ValueKey<String>('text-search-load-more'),
                onPressed: _isLoadingTextSearch
                    ? null
                    : () => _runTextSearch(loadMore: true),
                icon: const Icon(Icons.expand_more),
                label: const Text('Load more'),
              ),
          ],
        ),
        if (_isLoadingTextSearch)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_textSearchResults.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            '${_textSearchResults.length} result(s)'
            '${isPaged ? ' across $_loadedTextSearchPages page(s)' : ''}'
            '${_nextPageToken == null ? '' : ' · more available'}',
          ),
          if (_searchUri != null) SelectableText(_searchUri!),
          const SizedBox(height: 8),
          for (final place in _textSearchResults)
            Card(
              child: ListTile(
                dense: true,
                title: Text(place.displayName?.text ?? place.id),
                subtitle: place.formattedAddress == null
                    ? null
                    : Text(place.formattedAddress!),
              ),
            ),
        ],
        if (_textSearchError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_safeErrorText(_textSearchError!)),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _openConfiguration(BuildContext context) async {
    final updated = await showModalBottomSheet<DemoConfiguration>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ConfigurationSheet(initial: _configuration),
    );
    if (!mounted || updated == null) {
      return;
    }

    _cancelTextSearch();
    _controller.clear();
    setState(() {
      _configuration = updated;
      _selection = null;
      _autocompleteError = null;
      _clearTextSearchResults();
    });
  }

  Future<void> _runTextSearch({bool loadMore = false}) async {
    final query = _textSearchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _textSearchValidationError = 'Enter a place search.';
      });
      return;
    }
    if (loadMore && _nextPageToken == null) {
      return;
    }

    _cancelTextSearch();
    final generation = _textSearchGeneration;
    final cancellationToken = PlacesCancellationToken();
    _textSearchCancellation = cancellationToken;
    final pageToken = loadMore ? _nextPageToken : null;
    setState(() {
      _isLoadingTextSearch = true;
      _textSearchError = null;
      _textSearchValidationError = null;
      if (!loadMore) {
        _textSearchResults.clear();
        _nextPageToken = null;
        _searchUri = null;
        _loadedTextSearchPages = 0;
      }
    });

    final request = TextSearchRequest(
      textQuery: query,
      fields: const <PlaceField>{
        ...PlaceFieldPresets.minimal,
        PlaceField.businessStatus,
        PlaceField.priceLevel,
        PlaceField.priceRange,
        PlaceField.openingDate,
        PlaceField.googleMapsTypeLabel,
      },
      languageCode: _demoLocale.locale.languageCode,
      regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
      pageSize: _configuration.pageSize,
      pageToken: pageToken,
      priceLevels: const <PlacePriceLevel>[
        PlacePriceLevel.inexpensive,
        PlacePriceLevel.moderate,
      ],
      includePureServiceAreaBusinesses: true,
      includeFutureOpeningBusinesses: true,
    );

    try {
      if (_configuration.textSearchMode == TextSearchMode.paged) {
        final page = await _client.searchTextPage(
          request,
          cancellationToken: cancellationToken,
        );
        if (!_canApplyTextSearch(generation)) {
          return;
        }
        setState(() {
          _textSearchResults.addAll(page.results);
          _nextPageToken = page.hasNextPage ? page.nextPageToken : null;
          _searchUri = page.searchUri ?? _searchUri;
          _loadedTextSearchPages++;
        });
      } else {
        final results = await _client.searchText(
          request,
          cancellationToken: cancellationToken,
        );
        if (!_canApplyTextSearch(generation)) {
          return;
        }
        setState(() {
          _textSearchResults.addAll(results);
          _loadedTextSearchPages = 1;
        });
      }
    } catch (error) {
      if (!_canApplyTextSearch(generation)) {
        return;
      }
      if (error case PlacesException(kind: PlacesErrorKind.cancellation)) {
        return;
      }
      setState(() {
        _textSearchError = error;
      });
    } finally {
      if (_canApplyTextSearch(generation)) {
        setState(() {
          _isLoadingTextSearch = false;
          _textSearchCancellation = null;
        });
      }
    }
  }

  bool _canApplyTextSearch(int generation) =>
      mounted && generation == _textSearchGeneration;

  void _cancelTextSearch() {
    _textSearchGeneration++;
    _textSearchCancellation?.cancel();
    _textSearchCancellation = null;
  }

  void _clearTextSearch() {
    _cancelTextSearch();
    _textSearchController.clear();
    setState(_clearTextSearchResults);
  }

  void _clearTextSearchResults() {
    _textSearchResults.clear();
    _nextPageToken = null;
    _searchUri = null;
    _loadedTextSearchPages = 0;
    _isLoadingTextSearch = false;
    _textSearchError = null;
    _textSearchValidationError = null;
  }

  PlacesStrings _stringsFor(DemoLocale locale) {
    return switch (locale) {
      DemoLocale.english => const PlacesStrings(
        searchHint: 'Search for a place',
        overlayTitle: 'Search places',
        distanceUnitMeters: 'm',
      ),
      DemoLocale.hebrew => const PlacesStrings(
        searchHint: 'חיפוש מקום',
        loadingText: 'טוען תוצאות…',
        noResultsText: 'לא נמצאו תוצאות',
        errorText: 'אירעה שגיאה בטעינת המקומות',
        retryText: 'נסה שוב',
        poweredByGoogleLabel: 'מופעל על ידי Google',
        overlayTitle: 'חיפוש מקומות',
        closeLabel: 'סגור',
        clearLabel: 'נקה חיפוש',
        distanceUnitMeters: 'מ׳',
      ),
      DemoLocale.arabic => const PlacesStrings(
        searchHint: 'ابحث عن مكان',
        loadingText: 'جار تحميل النتائج…',
        noResultsText: 'لا توجد نتائج مطابقة',
        errorText: 'تعذر تحميل الأماكن',
        retryText: 'إعادة المحاولة',
        poweredByGoogleLabel: 'مشغل بواسطة Google',
        overlayTitle: 'البحث عن الأماكن',
        closeLabel: 'إغلاق',
        clearLabel: 'مسح البحث',
        distanceUnitMeters: 'م',
      ),
    };
  }
}

class _ConfigurationSummary extends StatelessWidget {
  const _ConfigurationSummary({
    required this.configuration,
    required this.onOpen,
  });

  final DemoConfiguration configuration;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Current configuration',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey<String>('open-configuration'),
                  onPressed: onOpen,
                  icon: const Icon(Icons.tune),
                  label: const Text('Configuration'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 2,
              children: <Widget>[
                Chip(
                  label: Text(configuration.locale.label),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(configuration.widgetType.label),
                  visualDensity: VisualDensity.compact,
                ),
                Chip(
                  label: Text(configuration.textSearchMode.label),
                  visualDensity: VisualDensity.compact,
                ),
                if (configuration.textSearchMode == TextSearchMode.paged)
                  Chip(
                    label: Text('${configuration.pageSize} per page'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (configuration.fetchPlaceDetails)
                  const Chip(
                    label: Text('Place details'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (configuration.fetchTimeZone)
                  const Chip(
                    label: Text('Time zone'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (configuration.includeQueryPredictions)
                  const Chip(
                    label: Text('Query predictions'),
                    visualDensity: VisualDensity.compact,
                  ),
                if (configuration.showDistanceFromOrigin)
                  const Chip(
                    label: Text('Distance from origin'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationSheet extends StatefulWidget {
  const _ConfigurationSheet({required this.initial});

  final DemoConfiguration initial;

  @override
  State<_ConfigurationSheet> createState() => _ConfigurationSheetState();
}

class _ConfigurationSheetState extends State<_ConfigurationSheet> {
  late DemoConfiguration _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Configuration',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Close configuration',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: <Widget>[
                Text('Basics', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                DropdownButtonFormField<DemoLocale>(
                  key: const ValueKey<String>('configuration-language'),
                  initialValue: _draft.locale,
                  decoration: const InputDecoration(
                    labelText: 'Language',
                    border: OutlineInputBorder(),
                  ),
                  items: DemoLocale.values
                      .map(
                        (locale) => DropdownMenuItem<DemoLocale>(
                          value: locale,
                          child: Text(locale.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _draft = _draft.copyWith(locale: value));
                    }
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<WidgetType>(
                  key: const ValueKey<String>('configuration-widget-type'),
                  initialValue: _draft.widgetType,
                  decoration: const InputDecoration(
                    labelText: 'Widget type',
                    border: OutlineInputBorder(),
                  ),
                  items: WidgetType.values
                      .map(
                        (type) => DropdownMenuItem<WidgetType>(
                          value: type,
                          child: Text(type.label),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) {
                    if (value != null) {
                      setState(
                        () => _draft = _draft.copyWith(widgetType: value),
                      );
                    }
                  },
                ),
                const SizedBox(height: 20),
                const Text('Text Search results'),
                const SizedBox(height: 8),
                SegmentedButton<TextSearchMode>(
                  key: const ValueKey<String>('configuration-search-mode'),
                  segments: TextSearchMode.values
                      .map(
                        (mode) => ButtonSegment<TextSearchMode>(
                          value: mode,
                          label: Text(mode.label),
                        ),
                      )
                      .toList(growable: false),
                  selected: <TextSearchMode>{_draft.textSearchMode},
                  onSelectionChanged: (selection) {
                    setState(
                      () => _draft = _draft.copyWith(
                        textSearchMode: selection.first,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                ExpansionTile(
                  key: const ValueKey<String>('configuration-advanced'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: const Text('Advanced options'),
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.fetchPlaceDetails,
                      title: const Text('Fetch Place Details'),
                      subtitle: const Text(
                        'Resolve the selected suggestion into Place data.',
                      ),
                      onChanged: (value) => setState(
                        () =>
                            _draft = _draft.copyWith(fetchPlaceDetails: value),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.fetchTimeZone,
                      title: const Text('Fetch Time Zone'),
                      subtitle: const Text(
                        'Look up time-zone data after a place is selected.',
                      ),
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(fetchTimeZone: value),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _draft.includeQueryPredictions,
                      title: const Text('Include query predictions'),
                      subtitle: const Text(
                        'Mix suggested searches with place predictions.',
                      ),
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(
                          includeQueryPredictions: value,
                        ),
                      ),
                    ),
                    SwitchListTile(
                      key: const ValueKey<String>('configuration-origin'),
                      contentPadding: EdgeInsets.zero,
                      value: _draft.showDistanceFromOrigin,
                      title: const Text('Show distance from an origin'),
                      subtitle: const Text(
                        'Sends origin so Google returns a distance for each '
                        'suggestion. Uses a fixed demo coordinate.',
                      ),
                      onChanged: (value) => setState(
                        () => _draft = _draft.copyWith(
                          showDistanceFromOrigin: value,
                        ),
                      ),
                    ),
                    if (_draft.textSearchMode == TextSearchMode.paged)
                      DropdownButtonFormField<int>(
                        key: const ValueKey<String>('configuration-page-size'),
                        initialValue: _draft.pageSize,
                        decoration: const InputDecoration(
                          labelText: 'Results per page',
                          border: OutlineInputBorder(),
                        ),
                        items: const <int>[5, 10, 20]
                            .map(
                              (size) => DropdownMenuItem<int>(
                                value: size,
                                child: Text('$size'),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          if (value != null) {
                            setState(
                              () => _draft = _draft.copyWith(pageSize: value),
                            );
                          }
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  key: const ValueKey<String>('configuration-cancel'),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  key: const ValueKey<String>('configuration-apply'),
                  onPressed: () => Navigator.pop(context, _draft),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingConfigurationNotice extends StatelessWidget {
  const _MissingConfigurationNotice();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pass GOOGLE_MAPS_API_KEY or PLACES_PROXY_URL with --dart-define '
        'to run the example.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
