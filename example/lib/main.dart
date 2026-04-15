import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';

const _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

void main() {
  runApp(const ExampleApp());
}

enum WidgetType { textField, dialog, fullscreen }

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

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final PlacesClient _client = PlacesClient(apiKey: _apiKey);
  final PlacesAutocompleteController _controller =
      PlacesAutocompleteController();

  DemoLocale _demoLocale = DemoLocale.english;
  PlacesAutocompleteFieldMode _fieldMode = PlacesAutocompleteFieldMode.inline;
  PlaceSelection? _selection;
  Object? _lastError;
  WidgetType _widgetType = WidgetType.textField;
  bool _fetchTimeZoneOnSelection = false;

  @override
  void dispose() {
    _controller.dispose();
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'google_places_autocomplete example',
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
          appBar: AppBar(title: const Text('google_places_autocomplete')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: _apiKey.isEmpty
                ? const _MissingKeyNotice()
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
        const Text('Widget Locale', textAlign: TextAlign.center),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SegmentedButton<DemoLocale>(
              segments: DemoLocale.values
                  .map(
                    (locale) => ButtonSegment<DemoLocale>(
                      value: locale,
                      label: Text(locale.label),
                    ),
                  )
                  .toList(growable: false),
              selected: <DemoLocale>{_demoLocale},
              onSelectionChanged: (selection) {
                setState(() {
                  _demoLocale = selection.first;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Search Widget Type', textAlign: TextAlign.center),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            SegmentedButton<WidgetType>(
              segments: const <ButtonSegment<WidgetType>>[
                ButtonSegment<WidgetType>(
                  value: WidgetType.textField,
                  label: Text('Text Field'),
                ),
                ButtonSegment<WidgetType>(
                  value: WidgetType.dialog,
                  label: Text('Dialog'),
                ),
                ButtonSegment<WidgetType>(
                  value: WidgetType.fullscreen,
                  label: Text('Fullscreen'),
                ),
              ],
              selected: <WidgetType>{_widgetType},
              onSelectionChanged: (selection) {
                setState(() {
                  _widgetType = selection.first;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 24),
        SwitchListTile(
          dense: true,
          value: _fetchTimeZoneOnSelection,
          title: const Text('Fetch time zone on selection'),
          subtitle: const Text(
            'Uses Google Time Zone API after resolving the selected place coordinates.',
          ),
          onChanged: (value) {
            setState(() {
              _fetchTimeZoneOnSelection = value;
            });
          },
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
            strings: strings,
            languageCode: _demoLocale.locale.languageCode,
            regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
            fetchPlaceDetailsOnSelection: true,
            fetchTimeZoneOnSelection: _fetchTimeZoneOnSelection,
            selectionFields: PlaceFieldPresets.rich,
            fieldMode: _fieldMode,
            onSelection: (selection) {
              setState(() {
                _selection = selection;
                _lastError = null;
              });
            },
            onClearField: () {
              setState(() {
                _selection = null;
                _lastError = null;
              });
            },
            onError: (error) {
              setState(() {
                _lastError = error;
              });
            },
          ),
          const SizedBox(height: 24),
        ],
        if (_widgetType != WidgetType.textField) ...[
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
          if (_selection != null)
            Card(
              child: ListTile(
                title: Text(_selection!.suggestion.primaryText.text),
                subtitle: Text(_selection!.displayText),
              ),
            ),
        ],
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
        if (_lastError != null)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_lastError.toString()),
            ),
          ),
      ],
    );
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
      strings: strings,
      languageCode: _demoLocale.locale.languageCode,
      regionCode: _demoLocale.locale.countryCode?.toLowerCase(),
      fetchPlaceDetailsOnSelection: true,
      fetchTimeZoneOnSelection: _fetchTimeZoneOnSelection,
      selectionFields: mode == PlacesAutocompleteOverlayMode.dialog
          ? PlaceFieldPresets.recommended
          : PlaceFieldPresets.minimal,
      onError: (error) {
        setState(() {
          _lastError = error;
        });
      },
    );

    if (selection == null) {
      return;
    }

    setState(() {
      _selection = selection;
      _lastError = null;
    });
  }

  PlacesStrings _stringsFor(DemoLocale locale) {
    return switch (locale) {
      DemoLocale.english => const PlacesStrings(
        searchHint: 'Search for a place',
        overlayTitle: 'Search places',
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
      ),
    };
  }
}

class _MissingKeyNotice extends StatelessWidget {
  const _MissingKeyNotice();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Pass GOOGLE_MAPS_API_KEY with --dart-define to run the example.',
        textAlign: TextAlign.center,
      ),
    );
  }
}
