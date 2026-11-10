import 'dart:math';

/// Whether a device in [countryCode] shows road distances in miles.
///
/// True for `US`, `GB`, `LR` and `MM` (CLDR non-metric for road distance),
/// case-insensitive. `null`, empty or any other code is metric.
bool placesRegionUsesImperial(String? countryCode) =>
    const {'US', 'GB', 'LR', 'MM'}.contains(countryCode?.toUpperCase());

/// The distance text for a suggestion row, such as "850 m", "1.2 km",
/// "500 ft" or "0.8 mi".
///
/// Metric: under 1000 m the whole metres; up to 10 km one decimal; from 10 km
/// whole kilometres. Imperial: feet to the nearest 10 (at least 10 ft for any
/// non-zero distance) while that is below 0.1 mi, then one decimal up to
/// 10 mi, then whole miles. Every switch is decided on the rounded value, so
/// no "10.0 km", "0.0 mi" or "530 ft" appears. Negative input is treated as 0.
///
/// The number comes first, joined to the unit by a no-break space (a narrow
/// no-break space for `fr`). The decimal separator and digits follow CLDR 48
/// for [languageCode] and the optional, case-insensitive [regionCode] (a
/// country or UN M.49 code such as `419`): Western digits everywhere except
/// Arabic regions that use Arabic-Indic digits.
String formatPlacesDistance(
  int meters, {
  required bool imperial,
  required String languageCode,
  required String metersUnit,
  required String kilometersUnit,
  required String milesUnit,
  required String feetUnit,
  String? regionCode,
}) {
  final m = meters < 0 ? 0 : meters;
  final sep = _decimalSeparator(languageCode, regionCode);
  String tenths(int t) => '${t ~/ 10}$sep${t % 10}';
  String out(String number, String unit) {
    if (sep == _arabicSeparator) {
      number = number.replaceAllMapped(
        RegExp('[0-9]'),
        (d) => String.fromCharCode(d[0]!.codeUnitAt(0) + 0x630),
      );
    }
    return '$number${languageCode == 'fr' ? '\u202F' : '\u00A0'}$unit';
  }

  if (!imperial) {
    if (m < 1000) return out('$m', metersUnit);
    final t = (m + 50) ~/ 100; // tenths of a km, half up
    return out(t < 100 ? tenths(t) : '${(m + 500) ~/ 1000}', kilometersUnit);
  }
  // 1 ft = 0.3048 m, 1 mi = 1609.344 m; integer math, half up.
  final feet = m == 0 ? 0 : max(10, (m * 1000 + 1524) ~/ 3048 * 10);
  if (feet < 530) return out('$feet', feetUnit); // 0.1 mi is 528 ft
  final t = (m * 10000 + 804672) ~/ 1609344; // tenths of a mile
  return out(
    t < 100 ? tenths(t) : '${(m * 1000 + 804672) ~/ 1609344}',
    milesUnit,
  );
}

const _arabicSeparator = '\u066B';

// The one place that knows CLDR 48 separators; a separator of U+066B also
// means Arabic-Indic digits.
String _decimalSeparator(String languageCode, String? regionCode) {
  final r = regionCode?.toUpperCase();
  return switch (languageCode) {
    'ru' || 'fr' || 'pt' => ',',
    'de' => const {'CH', 'LI'}.contains(r) ? '.' : ',',
    'es' =>
      const {
            '419', 'BR', 'BZ', 'CU', 'DO', 'GT', 'HN', 'MX', 'NI', 'PA', //
            'PE', 'PR', 'SV', 'US',
          }.contains(r)
          ? '.'
          : ',',
    'en' =>
      const {
            'AT', 'BE', 'CZ', 'DE', 'DK', 'EE', 'ES', 'FI', 'FR', 'GE', //
            'HU', 'ID', 'IT', 'LT', 'LV', 'NL', 'NO', 'PL', 'PT', 'RO', //
            'SE', 'SI', 'SK', 'UA', 'ZA',
          }.contains(r)
          ? ','
          : '.',
    'ar' =>
      const {
            'BH', 'DJ', 'EG', 'ER', 'IL', 'IQ', 'JO', 'KM', 'KW', 'LB', //
            'MR', 'OM', 'PS', 'QA', 'SA', 'SD', 'SO', 'SS', 'SY', 'TD', //
            'YE',
          }.contains(r)
          ? _arabicSeparator
          : const {'DZ', 'LY', 'MA', 'TN'}.contains(r)
          ? ','
          : '.',
    _ => '.', // he and anything unknown
  };
}
