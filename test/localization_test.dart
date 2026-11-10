// The 0.8.0 acceptance gate, as the widgets render it: every language in every
// mode, direction, fallback, overrides, semantics, legacy hosts, large text and
// high contrast. Resolution tables and the override merge themselves are
// proven in places_strings_test.dart; this file proves the widgets use them.
//
// package:flutter/material.dart is imported only to build a legacy host, as in
// legacy_host_test.dart.
// ignore_for_file: deprecated_member_use
import 'dart:async';

import 'package:flutter/material.dart' as legacy;
import 'package:flutter_localizations/flutter_localizations.dart'
    as legacy_l10n;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_ar.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_de.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_es.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_fr.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_he.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_pt.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_ru.dart';
import 'package:material_ui/material_ui.dart';

const _english = PlacesStrings();

const _bundles = <String, PlacesStrings>{
  'en': _english,
  'he': placesStringsHe,
  'ar': placesStringsAr,
  'ru': placesStringsRu,
  'fr': placesStringsFr,
  'de': placesStringsDe,
  'es': placesStringsEs,
  'pt': placesStringsPt,
};

TextDirection _directionOf(String language) =>
    language == 'he' || language == 'ar'
    ? TextDirection.rtl
    : TextDirection.ltr;

const _modes = PlacesAutocompleteFieldMode.values;

enum _Answer { loading, error, empty, results }

const _place = PlaceSuggestion(
  placeId: 'place-1',
  placeResourceName: 'places/place-1',
  fullText: StructuredText(text: 'Coffee Lab, Main Street'),
  primaryText: StructuredText(text: 'Coffee Lab'),
  secondaryText: StructuredText(text: 'Main Street'),
);

const _query = QuerySuggestion(
  fullText: StructuredText(text: 'coffee near me'),
);

/// Answers searches with [answer]; place details never arrive, so a picked
/// place stays in selection loading. Photos fail at once.
class _Backend implements PlacesBackend {
  _Answer answer = _Answer.results;

  Future<List<T>> _reply<T>(List<T> results) => switch (answer) {
    _Answer.loading => Completer<List<T>>().future,
    _Answer.error => Future<List<T>>.error(
      const PlacesException(
        'Offline.',
        kind: PlacesErrorKind.network,
        retryable: true,
      ),
    ),
    _Answer.empty => Future<List<T>>.value(<T>[]),
    _Answer.results => Future<List<T>>.value(results),
  };

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _reply(const <PlaceSuggestion>[_place]);

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => _reply(const <AutocompleteSuggestion>[_place, _query]);

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) => Completer<PlaceData>().future;

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {}

  @override
  Future<void> close() async {}

  // Nothing else is reached; fetchPhotoMedia fails at once.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// An app on [locale] — material_ui, or a [legacyHost] on
/// package:flutter/material.dart — localized by flutter_localizations.
Widget _app(
  Locale locale,
  Widget body, {
  bool legacyHost = false,
  MediaQueryData Function(MediaQueryData)? media,
}) {
  final supported = <Locale>{
    locale,
    for (final language in _bundles.keys) Locale(language),
  }.toList();
  final TransitionBuilder? builder = media == null
      ? null
      : (context, child) =>
            MediaQuery(data: media(MediaQuery.of(context)), child: child!);
  if (legacyHost) {
    return legacy.MaterialApp(
      locale: locale,
      supportedLocales: supported,
      localizationsDelegates: legacy_l10n.GlobalMaterialLocalizations.delegates,
      builder: builder,
      home: legacy.Scaffold(body: body),
    );
  }
  return MaterialApp(
    locale: locale,
    supportedLocales: supported,
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    builder: builder,
    home: Scaffold(body: body),
  );
}

/// Pumps [mode] of the search in an app on [locale], opened and settled.
Future<_Backend> _open(
  WidgetTester tester,
  PlacesAutocompleteFieldMode mode,
  Locale locale, {
  PlacesStrings strings = const PlacesStrings(),
  bool legacyHost = false,
  MediaQueryData Function(MediaQueryData)? media,
}) async {
  final backend = _Backend();
  final client = PlacesClient.testing(apiKey: 'test', backend: backend);
  await tester.pumpWidget(
    _app(
      locale,
      PlacesAutocompleteField(
        client: client,
        fieldMode: mode,
        strings: strings,
        includeQueryPredictions: true,
      ),
      legacyHost: legacyHost,
      media: media,
    ),
  );
  if (mode != PlacesAutocompleteFieldMode.inline) {
    // The launcher opens the search through PlacesAutocompleteOverlay.show.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
  }
  return backend;
}

/// The search's own text field: in the dialog or fullscreen search, not the
/// launcher behind it.
Finder _searchField() {
  final overlay = find.byType(PlacesAutocompleteOverlay);
  final fields = find.byType(TextField);
  return overlay.evaluate().isEmpty
      ? fields
      : find.descendant(of: overlay, matching: fields);
}

/// Types [text] with the backend answering [answer], and shows the result.
Future<void> _search(
  WidgetTester tester,
  _Backend backend,
  _Answer answer,
  String text,
) async {
  backend.answer = answer;
  await tester.enterText(_searchField(), text);
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

/// [text] is shown, and its English original is not.
void _shows(String text, String english) {
  expect(find.text(text), findsWidgets);
  if (text != english) {
    expect(find.text(english), findsNothing, reason: 'English "$english"');
  }
}

/// The error row: the message at the tile's start edge, and the retry button
/// at the end beside it or, wrapped, under it at the start.
void _expectErrorRow(WidgetTester tester, PlacesStrings s, bool rtl) {
  final message = find.text(s.errorText);
  final bar = tester.getRect(
    find.ancestor(of: message, matching: find.byType(OverflowBar)),
  );
  final error = tester.getRect(message);
  final retry = tester.getRect(find.widgetWithText(TextButton, s.retryText));
  double start(Rect r) => rtl ? r.right : r.left;
  double end(Rect r) => rtl ? r.left : r.right;
  expect(start(error), moreOrLessEquals(start(bar)));
  if (retry.top >= error.bottom) {
    expect(start(retry), moreOrLessEquals(start(bar)), reason: 'wrapped');
  } else {
    expect(end(retry), moreOrLessEquals(end(bar)), reason: 'side by side');
  }
}

double _centerX(WidgetTester tester, Finder finder) =>
    tester.getCenter(finder).dx;

/// Drives every state of the open [mode] and checks each visible string,
/// semantics label and the layout direction against [s] and [direction].
Future<void> _expectLocalized(
  WidgetTester tester,
  _Backend backend,
  PlacesAutocompleteFieldMode mode,
  PlacesStrings s,
  TextDirection direction,
) async {
  final rtl = direction == TextDirection.rtl;
  final field = _searchField();
  final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
  _shows(s.searchHint, _english.searchHint);

  switch (mode) {
    case PlacesAutocompleteFieldMode.inline:
      break;
    case PlacesAutocompleteFieldMode.dialog:
      _shows(s.overlayTitle, _english.overlayTitle);
      final close = find.byTooltip(s.closeLabel);
      expect(close, findsOneWidget);
      expect(
        tester.getSemantics(close),
        containsSemantics(tooltip: s.closeLabel),
      );
      final title = find
          .descendant(
            of: find.byType(Dialog),
            matching: find.text(s.overlayTitle),
          )
          .first; // The title; the empty field's hint may read the same.
      // The close button sits at the end of the title row.
      expect(_centerX(tester, close) < _centerX(tester, title), rtl);
    case PlacesAutocompleteFieldMode.fullscreen:
      final back = find.byTooltip(s.closeLabel);
      expect(back, findsOneWidget);
      expect(
        tester.getSemantics(back),
        containsSemantics(tooltip: s.closeLabel),
      );
      // The back button leads the top bar: right in RTL.
      expect(_centerX(tester, back) > width / 2, rtl);
      // The title is the route's name for screen readers.
      final named = find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.namesRoute ?? false),
      );
      expect(
        tester.getSemantics(named),
        containsSemantics(label: s.overlayTitle, namesRoute: true),
      );
  }

  await _search(tester, backend, _Answer.loading, 'c');
  _shows(s.loadingText, _english.loadingText);

  await _search(tester, backend, _Answer.error, 'co');
  _shows(s.errorText, _english.errorText);
  _shows(s.retryText, _english.retryText);
  _expectErrorRow(tester, s, rtl);

  await _search(tester, backend, _Answer.empty, 'cof');
  _shows(s.noResultsText, _english.noResultsText);

  await _search(tester, backend, _Answer.results, 'coff');
  expect(
    find.bySemanticsLabel('${s.placeSuggestionLabel}: Coffee Lab, Main Street'),
    findsOneWidget,
  );
  expect(
    find.bySemanticsLabel('${s.querySuggestionLabel}: coffee near me'),
    findsOneWidget,
  );
  expect(find.bySemanticsLabel(s.poweredByGoogleLabel), findsOneWidget);
  final clear = find.byTooltip(s.clearLabel);
  expect(tester.getSemantics(clear), containsSemantics(tooltip: s.clearLabel));
  // The clear button is the field's suffix: its left end in RTL.
  expect(_centerX(tester, clear) < _centerX(tester, field), rtl);

  final probes = <Finder>[
    field,
    find.text('Coffee Lab'),
    if (mode == PlacesAutocompleteFieldMode.dialog) find.byType(Dialog),
    if (mode == PlacesAutocompleteFieldMode.fullscreen)
      find.byType(PlacesAutocompleteOverlay),
  ];
  for (final probe in probes) {
    expect(
      Directionality.of(tester.element(probe)),
      direction,
      reason: '$probe',
    );
  }

  await tester.tap(find.text('Coffee Lab'));
  await tester.pump();
  expect(find.bySemanticsLabel(s.selectionLoadingLabel), findsOneWidget);
  expect(tester.takeException(), isNull);
}

/// [base] with the hint and the selection-loading label replaced, for the
/// fields [_expectLocalized] reads.
PlacesStrings _overridden(PlacesStrings base) => PlacesStrings(
  searchHint: 'x',
  loadingText: base.loadingText,
  noResultsText: base.noResultsText,
  errorText: base.errorText,
  retryText: base.retryText,
  poweredByGoogleLabel: base.poweredByGoogleLabel,
  overlayTitle: base.overlayTitle,
  closeLabel: base.closeLabel,
  clearLabel: base.clearLabel,
  placeSuggestionLabel: base.placeSuggestionLabel,
  querySuggestionLabel: base.querySuggestionLabel,
  selectionLoadingLabel: 'y',
);

void main() {
  group('eight languages in every mode', () {
    for (final MapEntry(key: language, value: bundle) in _bundles.entries) {
      for (final mode in _modes) {
        testWidgets('$language, ${mode.name}', (tester) async {
          final backend = await _open(tester, mode, Locale(language));
          await _expectLocalized(
            tester,
            backend,
            mode,
            bundle,
            _directionOf(language),
          );
        });
      }
    }
  });

  group('fallback and overrides', () {
    final regional = <(Locale, String, PlacesAutocompleteFieldMode)>[
      (const Locale('fr', 'CA'), 'fr', PlacesAutocompleteFieldMode.inline),
      (const Locale('pt', 'BR'), 'pt', PlacesAutocompleteFieldMode.dialog),
      (const Locale('pt', 'PT'), 'pt', PlacesAutocompleteFieldMode.fullscreen),
      (const Locale('es', 'MX'), 'es', PlacesAutocompleteFieldMode.inline),
      (const Locale('ar', 'EG'), 'ar', PlacesAutocompleteFieldMode.dialog),
      // A language the package does not bundle gets English.
      (const Locale('ja'), 'en', PlacesAutocompleteFieldMode.fullscreen),
    ];
    for (final (locale, language, mode) in regional) {
      testWidgets('$locale gets $language, ${mode.name}', (tester) async {
        final backend = await _open(tester, mode, locale);
        // The app really runs on the regional locale, not its base.
        expect(Localizations.localeOf(tester.element(_searchField())), locale);
        await _expectLocalized(
          tester,
          backend,
          mode,
          _bundles[language]!,
          _directionOf(locale.languageCode),
        );
      });
    }

    for (final mode in _modes) {
      testWidgets('English strings in a Hebrew app stay right to left, '
          '${mode.name}', (tester) async {
        final backend = await _open(
          tester,
          mode,
          const Locale('he'),
          strings: const PlacesStrings(locale: Locale('en')),
        );
        await _expectLocalized(
          tester,
          backend,
          mode,
          _english,
          TextDirection.rtl,
        );
      });

      testWidgets('an override beats locale, which beats the app, '
          '${mode.name}', (tester) async {
        final backend = await _open(
          tester,
          mode,
          const Locale('he'),
          strings: const PlacesStrings(
            locale: Locale('fr'),
            searchHint: 'x',
            selectionLoadingLabel: 'y',
          ),
        );
        await _expectLocalized(
          tester,
          backend,
          mode,
          _overridden(placesStringsFr),
          TextDirection.rtl,
        );
      });
    }
  });

  // show() called directly, not through the field's launcher.
  for (final legacyHost in <bool>[false, true]) {
    for (final mode in <PlacesAutocompleteOverlayMode>[
      PlacesAutocompleteOverlayMode.dialog,
      PlacesAutocompleteOverlayMode.fullscreen,
    ]) {
      testWidgets('show() in ${mode.name} mode from a Hebrew '
          '${legacyHost ? 'legacy' : 'material_ui'} app', (tester) async {
        final client = PlacesClient.testing(
          apiKey: 'test',
          backend: _Backend(),
        );
        await tester.pumpWidget(
          _app(
            const Locale('he'),
            // Widgets-layer opener, so it builds in either host.
            Builder(
              builder: (context) => GestureDetector(
                onTap: () => PlacesAutocompleteOverlay.show(
                  context,
                  client: client,
                  mode: mode,
                ),
                child: const Text('Open'),
              ),
            ),
            legacyHost: legacyHost,
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.byTooltip(placesStringsHe.closeLabel), findsOneWidget);
        await tester.enterText(_searchField(), 'c');
        await tester.pump();
        expect(find.byTooltip(placesStringsHe.clearLabel), findsOneWidget);
      });
    }
  }

  // One right-to-left language is enough here: legacy_host_test.dart probes
  // Hebrew direction on every surface.
  group('legacy host', () {
    for (final mode in _modes) {
      testWidgets('ar, ${mode.name}', (tester) async {
        final backend = await _open(
          tester,
          mode,
          const Locale('ar'),
          legacyHost: true,
        );
        await _expectLocalized(
          tester,
          backend,
          mode,
          placesStringsAr,
          TextDirection.rtl,
        );
      });
    }
  });

  // At normal size, in the test font, where the message fits on one line.
  for (final mode in _modes) {
    testWidgets('a long retry label wraps under the error, ${mode.name}', (
      tester,
    ) async {
      const retryText = 'Try loading the matching places once again';
      final backend = await _open(
        tester,
        mode,
        const Locale('en'),
        strings: const PlacesStrings(retryText: retryText),
      );
      await _search(tester, backend, _Answer.error, 'co');

      expect(tester.takeException(), isNull);
      final error = tester.getRect(find.text(_english.errorText));
      final retry = tester.getRect(find.widgetWithText(TextButton, retryText));
      // The whole message on one line (the test font's glyphs are 1 em, at
      // 14), not squeezed beside the button; the button wrapped under it.
      expect(error.width, greaterThanOrEqualTo(_english.errorText.length * 14));
      expect(retry.top, greaterThanOrEqualTo(error.bottom));
      _expectErrorRow(tester, const PlacesStrings(retryText: retryText), false);
    });
  }

  group('large text and high contrast on a phone', () {
    final medias = <String, MediaQueryData Function(MediaQueryData)>{
      'no overflow': (m) => m.copyWith(textScaler: const TextScaler.linear(2)),
      'high contrast + bold text: no overflow': (m) => m.copyWith(
        textScaler: const TextScaler.linear(2),
        highContrast: true,
        boldText: true,
      ),
    };
    for (final language in <String>['de', 'ru']) {
      for (final mode in _modes) {
        for (final MapEntry(key: name, value: media) in medias.entries) {
          testWidgets('$language, ${mode.name}, $name', (tester) async {
            tester.view
              ..physicalSize = const Size(390, 844) * 3
              ..devicePixelRatio = 3;
            addTearDown(tester.view.reset);
            final s = _bundles[language]!;
            final screen = Offset.zero & const Size(390, 844);
            void onScreen(Finder finder) {
              final rect = tester.getRect(finder);
              expect(
                screen.contains(rect.topLeft) &&
                    screen.contains(rect.bottomRight - const Offset(1, 1)),
                isTrue,
                reason: '$finder at $rect',
              );
            }

            final backend = await _open(
              tester,
              mode,
              Locale(language),
              media: media,
            );
            expect(tester.takeException(), isNull);
            if (mode == PlacesAutocompleteFieldMode.dialog) {
              onScreen(
                find
                    .descendant(
                      of: find.byType(Dialog),
                      matching: find.text(s.overlayTitle),
                    )
                    .first,
              );
            }

            await _search(tester, backend, _Answer.loading, 'c');
            expect(find.text(s.loadingText), findsOneWidget);
            expect(tester.takeException(), isNull);

            await _search(tester, backend, _Answer.error, 'co');
            onScreen(find.widgetWithText(TextButton, s.retryText));
            _expectErrorRow(tester, s, false);
            expect(tester.takeException(), isNull);

            await _search(tester, backend, _Answer.results, 'cof');
            onScreen(find.text('Coffee Lab'));
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  });
}
