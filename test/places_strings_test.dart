import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_ar.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_de.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_es.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_fr.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_he.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_pt.dart';
import 'package:google_places_sdk_flutter/src/widgets/l10n/places_strings_ru.dart';
import 'package:google_places_sdk_flutter/src/widgets/places_strings.dart';

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

/// Every string, by getter name.
Map<String, String> _fields(PlacesStrings s) => <String, String>{
  'searchHint': s.searchHint,
  'loadingText': s.loadingText,
  'noResultsText': s.noResultsText,
  'errorText': s.errorText,
  'retryText': s.retryText,
  'poweredByGoogleLabel': s.poweredByGoogleLabel,
  'overlayTitle': s.overlayTitle,
  'closeLabel': s.closeLabel,
  'clearLabel': s.clearLabel,
  'placeSuggestionLabel': s.placeSuggestionLabel,
  'querySuggestionLabel': s.querySuggestionLabel,
  'distanceUnitMeters': s.distanceUnitMeters,
  'distanceUnitKilometers': s.distanceUnitKilometers,
  'distanceUnitMiles': s.distanceUnitMiles,
  'distanceUnitFeet': s.distanceUnitFeet,
  'selectionLoadingLabel': s.selectionLoadingLabel,
  'photoAttributionPrefix': s.photoAttributionPrefix,
  'viewOnGoogleMapsText': s.viewOnGoogleMapsText,
};

/// Strings a language legitimately writes as English does: the
/// international unit symbols. Listed by (language, field), never by value.
final _sameAsEnglish = <(String, String)>{
  ('fr', 'distanceUnitMeters'),
  ('fr', 'distanceUnitKilometers'),
  ('fr', 'distanceUnitMiles'),
  for (final language in <String>['de', 'es', 'pt']) ...<(String, String)>{
    (language, 'distanceUnitMeters'),
    (language, 'distanceUnitKilometers'),
    (language, 'distanceUnitMiles'),
    (language, 'distanceUnitFeet'),
  },
};

/// Resolves [strings] under an app whose active locale is [appLocale], or
/// under no `Localizations` at all when it is `null`.
Future<PlacesStrings> _resolve(
  WidgetTester tester,
  Locale? appLocale, [
  PlacesStrings strings = const PlacesStrings(),
]) async {
  late PlacesStrings resolved;
  final probe = Builder(
    builder: (context) {
      resolved = resolvePlacesStrings(context, strings);
      return const SizedBox();
    },
  );
  await tester.pumpWidget(
    appLocale == null
        ? probe
        : Localizations(
            locale: appLocale,
            delegates: const <LocalizationsDelegate<dynamic>>[
              DefaultWidgetsLocalizations.delegate,
            ],
            child: probe,
          ),
  );
  return resolved;
}

/// Overrides one getter, as an app could in 0.7.x.
class _ExtendedStrings extends PlacesStrings {
  const _ExtendedStrings({super.locale});

  @override
  String get searchHint => 'EXT';
}

/// Implements the interface: every string is 'IMPL'.
class _ImplementedStrings implements PlacesStrings {
  const _ImplementedStrings();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      invocation.memberName == #locale ||
          invocation.memberName == #distanceUnits
      ? null
      : 'IMPL';
}

void main() {
  testWidgets('a subclass is shown as-is, with its locale resolved', (
    tester,
  ) async {
    final resolved = await _resolve(
      tester,
      const Locale('he'),
      const _ExtendedStrings(locale: Locale('de')),
    );
    expect(_fields(resolved), <String, String>{
      ..._fields(_english),
      'searchHint': 'EXT',
    });
    expect(resolved.locale, const Locale('de'));
    expect(resolved.distanceUnits, isNotNull);
  });

  testWidgets('an implementation is shown as-is', (tester) async {
    final resolved = await _resolve(
      tester,
      const Locale('he'),
      const _ImplementedStrings(),
    );
    expect(_fields(resolved).values.toSet(), <String>{'IMPL'});
    expect(resolved.locale, const Locale('he'));
  });

  group('the app locale picks the bundle', () {
    final table = <(Locale?, String)>[
      for (final language in _bundles.keys) (Locale(language), language),
      (const Locale('fr', 'CA'), 'fr'),
      (const Locale('pt', 'BR'), 'pt'),
      (const Locale('pt', 'PT'), 'pt'),
      (const Locale('ar', 'EG'), 'ar'),
      // The deprecated Hebrew code; Locale canonicalizes it to he.
      (const Locale('iw'), 'he'),
      (
        const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hant',
          countryCode: 'TW',
        ),
        'en',
      ),
      (const Locale('tlh'), 'en'),
      (null, 'en'),
    ];
    for (final (locale, language) in table) {
      testWidgets('$locale gets $language', (tester) async {
        final resolved = await _resolve(tester, locale);
        expect(_fields(resolved), _fields(_bundles[language]!));
        expect(resolved.locale, locale);
      });
    }
  });

  testWidgets('locale beats the app locale', (tester) async {
    final resolved = await _resolve(
      tester,
      const Locale('he'),
      const PlacesStrings(locale: Locale('de', 'AT')),
    );
    expect(_fields(resolved), _fields(placesStringsDe));
    expect(resolved.locale, const Locale('de', 'AT'));
  });

  testWidgets('an override replaces only its own string', (tester) async {
    final resolved = await _resolve(
      tester,
      const Locale('he'),
      const PlacesStrings(searchHint: 'x', distanceUnitFeet: 'y'),
    );
    expect(_fields(resolved), <String, String>{
      ..._fields(placesStringsHe),
      'searchHint': 'x',
      'distanceUnitFeet': 'y',
    });
  });

  testWidgets('an override also wins over an explicit locale', (tester) async {
    final resolved = await _resolve(
      tester,
      const Locale('en'),
      const PlacesStrings(locale: Locale('ar'), retryText: 'x'),
    );
    expect(_fields(resolved), <String, String>{
      ..._fields(placesStringsAr),
      'retryText': 'x',
    });
  });

  test('getters read outside a widget are the override or English', () {
    const strings = PlacesStrings(locale: Locale('he'), searchHint: 'x');
    expect(strings.searchHint, 'x');
    expect(strings.noResultsText, 'No matching places found.');
    expect(_fields(const PlacesStrings()), _fields(_english));
  });

  group('distance units', () {
    for (final (country, units) in <(String?, PlacesDistanceUnits)>[
      ('US', PlacesDistanceUnits.imperial),
      ('GB', PlacesDistanceUnits.imperial),
      ('IL', PlacesDistanceUnits.metric),
      (null, PlacesDistanceUnits.metric),
    ]) {
      testWidgets('a device in $country defaults to ${units.name}', (
        tester,
      ) async {
        tester.platformDispatcher.localeTestValue = Locale('en', country);
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        expect((await _resolve(tester, null)).distanceUnits, units);
      });
    }

    for (final units in PlacesDistanceUnits.values) {
      testWidgets('${units.name} set explicitly beats the device region', (
        tester,
      ) async {
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        for (final country in <String>['US', 'IL']) {
          tester.platformDispatcher.localeTestValue = Locale('en', country);
          final resolved = await _resolve(
            tester,
            null,
            PlacesStrings(distanceUnits: units),
          );
          expect(resolved.distanceUnits, units, reason: country);
        }
      });
    }
  });

  // _fields is kept by hand; a string missing from it would skip every check
  // here. Reads the source, so the VM only.
  test('_fields lists every string', testOn: 'vm', () {
    final source = File(
      'lib/src/widgets/places_strings.dart',
    ).readAsStringSync();
    expect(
      _fields(_english),
      hasLength('  String get '.allMatches(source).length),
    );
  });

  group('every bundle is complete', () {
    for (final MapEntry(key: language, value: bundle) in _bundles.entries) {
      test(language, () {
        expect(bundle.locale, isNull);
        expect(bundle.distanceUnits, isNull);
        final english = _fields(_english);
        for (final MapEntry(key: field, value: text) in _fields(
          bundle,
        ).entries) {
          final where = '$language.$field';
          expect(text, isNotEmpty, reason: where);
          expect(text, text.trim(), reason: where);
          expect(text, isNot(contains('...')), reason: '$where: use …');
          if (language != 'en' && !_sameAsEnglish.contains((language, field))) {
            expect(text, isNot(english[field]), reason: '$where is English');
          }
        }
      });
    }

    test('the allowlist only lists strings that are English', () {
      final english = _fields(_english);
      for (final (language, field) in _sameAsEnglish) {
        expect(
          _fields(_bundles[language]!)[field],
          english[field],
          reason: '$language.$field is translated; drop it from the list',
        );
      }
    });

    test('Google keeps its Latin spelling', () {
      for (final MapEntry(key: language, value: bundle) in _bundles.entries) {
        expect(
          bundle.poweredByGoogleLabel,
          contains('Google'),
          reason: language,
        );
        expect(
          bundle.viewOnGoogleMapsText,
          contains('Google'),
          reason: language,
        );
      }
    });
  });
}
