import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/src/widgets/places_distance.dart';

String fmt(
  int m, {
  bool imperial = false,
  String lang = 'en',
  String? region,
}) => formatPlacesDistance(
  m,
  imperial: imperial,
  languageCode: lang,
  regionCode: region,
  metersUnit: 'm',
  kilometersUnit: 'km',
  milesUnit: 'mi',
  feetUnit: 'ft',
);

void main() {
  const nb = ' ';

  test('metric rounding and switch points', () {
    const cases = {
      -5: '0${nb}m',
      0: '0${nb}m',
      850: '850${nb}m',
      999: '999${nb}m',
      1000: '1.0${nb}km',
      1234: '1.2${nb}km',
      9949: '9.9${nb}km',
      9950: '10${nb}km',
      9960: '10${nb}km',
      12400: '12${nb}km',
      12500: '13${nb}km',
    };
    cases.forEach((m, text) => expect(fmt(m), text, reason: '$m m'));
  });

  test('imperial rounding and switch points', () {
    const cases = {
      -5: '0${nb}ft',
      0: '0${nb}ft',
      1: '10${nb}ft', // never "0 ft" for a non-zero distance
      50: '160${nb}ft',
      160: '520${nb}ft',
      161: '0.1${nb}mi', // 528 ft is 0.1 mi; no "530 ft" beside it
      1000: '0.6${nb}mi',
      1609: '1.0${nb}mi',
      16000: '9.9${nb}mi',
      16012: '9.9${nb}mi',
      16050: '10${nb}mi', // rounded 9.97 mi is 10, not "10.0"
      16093: '10${nb}mi',
      40000: '25${nb}mi',
    };
    cases.forEach(
      (m, text) => expect(fmt(m, imperial: true), text, reason: '$m m'),
    );
  });

  test('imperial output is monotonic across the feet/miles boundary', () {
    num valueOf(String s) => num.parse(s.split(nb).first);
    final feet = <int>[], miles = <num>[];
    for (var m = 0; m < 400; m++) {
      final s = fmt(m, imperial: true);
      if (s.endsWith('ft')) {
        feet.add(valueOf(s).toInt());
      } else {
        miles.add(valueOf(s));
      }
    }
    expect(feet, orderedEquals([...feet]..sort()));
    expect(feet.last, lessThan(528));
    expect(miles.first, greaterThan(0));
  });

  test('decimal separator per language and region (CLDR 48)', () {
    // (language, region, expected number for 1234 m)
    const cases = [
      ('en', null, '1.2'),
      ('en', 'US', '1.2'),
      ('en', 'DE', '1,2'),
      ('en', 'za', '1,2'), // lowercase
      ('he', 'IL', '1.2'),
      ('ru', null, '1,2'),
      ('fr', 'CA', '1,2'),
      ('pt', 'BR', '1,2'),
      ('de', null, '1,2'),
      ('de', 'AT', '1,2'),
      ('de', 'CH', '1.2'),
      ('de', 'li', '1.2'),
      ('es', null, '1,2'),
      ('es', 'ES', '1,2'),
      ('es', 'MX', '1.2'),
      ('es', '419', '1.2'),
      ('es', 'us', '1.2'),
      ('ar', null, '1.2'),
      ('ar', 'AE', '1.2'),
      ('ar', 'MA', '1,2'),
      ('ar', 'dz', '1,2'),
      ('xx', 'DE', '1.2'), // unknown language
      ('', null, '1.2'),
    ];
    for (final (l, r, n) in cases) {
      expect(
        fmt(1234, lang: l, region: r),
        '$n${l == 'fr' ? '\u202F' : nb}km',
        reason: '$l-$r',
      );
    }
  });

  test('Arabic-Indic digits and separator for the regions that use them', () {
    expect(fmt(850, lang: 'ar', region: 'EG'), '\u0668\u0665\u0660${nb}m');
    expect(fmt(1234, lang: 'ar', region: 'sa'), '\u0661\u066B\u0662${nb}km');
    expect(fmt(12400, lang: 'ar', region: 'IL'), '\u0661\u0662${nb}km');
    expect(
      fmt(1000, imperial: true, lang: 'ar', region: 'EG'),
      '\u0660\u066B\u0666${nb}mi',
    );
    // Western digits when the region does not use Arabic-Indic digits.
    expect(fmt(850, lang: 'ar', region: 'MA'), '850${nb}m');
    expect(fmt(850, lang: 'ar'), '850${nb}m');
    expect(fmt(850, region: 'EG'), '850${nb}m'); // only for Arabic
  });

  test('joiner is U+00A0, U+202F for French, number first', () {
    expect(fmt(850), '850 m');
    expect(fmt(850, lang: 'de'), '850 m');
    expect(fmt(850, lang: 'fr'), '850 m');
    expect(fmt(1234, lang: 'fr'), '1,2 km');
  });

  test('region to imperial', () {
    for (final c in ['US', 'GB', 'LR', 'MM', 'us', 'gb']) {
      expect(placesRegionUsesImperial(c), isTrue, reason: c);
    }
    for (final c in ['IL', 'DE', '', null]) {
      expect(placesRegionUsesImperial(c), isFalse, reason: '$c');
    }
  });
}
