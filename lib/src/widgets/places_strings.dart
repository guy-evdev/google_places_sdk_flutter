/// @docImport 'places_autocomplete_builders.dart';
/// @docImport 'places_autocomplete_field.dart';
library;

import 'package:flutter/widgets.dart';

import 'l10n/places_strings_ar.dart';
import 'l10n/places_strings_de.dart';
import 'l10n/places_strings_es.dart';
import 'l10n/places_strings_fr.dart';
import 'l10n/places_strings_he.dart';
import 'l10n/places_strings_pt.dart';
import 'l10n/places_strings_ru.dart';
import 'places_distance.dart';

/// Which units the widgets show distances in.
enum PlacesDistanceUnits {
  /// Metres and kilometres.
  metric,

  /// Feet and miles.
  imperial,
}

/// The text of the package's widgets: the search field, the dialog and
/// fullscreen search, and the photo widgets.
///
/// **Nothing to set in a localized app.** The widgets follow the app's
/// language — the `Locale` its `MaterialApp` resolved — in English, Hebrew,
/// Arabic, Russian, French, German, Spanish and Portuguese. A regional locale
/// uses its language (`fr-CA` gets French), and any other language gets
/// English.
///
/// Set a string to replace that one string only; every string you leave out
/// stays in the widgets' language. In a Hebrew app, this changes the hint and
/// keeps the rest Hebrew:
///
/// ```dart
/// const PlacesStrings(searchHint: 'חפשו מסעדה')
/// ```
///
/// Set [locale] to show the widgets in a language other than the app's, and
/// [distanceUnits] to choose kilometres or miles.
///
/// This is only the widgets' own text. The language of Google's results —
/// place names and addresses — is the separate `languageCode` option.
///
/// Reading a getter outside a widget returns the value you set, or English.
/// The strings a builder receives, such as [PlacesSuggestionItemData.strings],
/// are already in the widgets' language.
///
/// A subclass or implementation of this class is shown as-is: the widgets use
/// its getters for every string, and only its [locale] and [distanceUnits]
/// are resolved.
@immutable
class PlacesStrings {
  /// Creates the widgets' text. Every value you leave out follows the
  /// widgets' language: [locale] when set, otherwise the app's.
  const PlacesStrings({
    this.locale,
    this.distanceUnits,
    this._searchHint,
    this._loadingText,
    this._noResultsText,
    this._errorText,
    this._retryText,
    this._poweredByGoogleLabel,
    this._overlayTitle,
    this._closeLabel,
    this._clearLabel,
    this._placeSuggestionLabel,
    this._querySuggestionLabel,
    this._distanceUnitMeters,
    this._distanceUnitKilometers,
    this._distanceUnitMiles,
    this._distanceUnitFeet,
    this._selectionLoadingLabel,
    this._photoAttributionPrefix,
    this._viewOnGoogleMapsText,
  });

  /// The language of the widgets' text, such as `Locale('he')`.
  ///
  /// When `null`, the widgets use the app's active locale. Set it to show the
  /// widgets in another language than the app. A language the package does
  /// not bundle gets English. Strings you set yourself are shown as you wrote
  /// them, whatever this is.
  ///
  /// It does not change the language of Google's results; that is the
  /// separate `languageCode` option.
  ///
  /// In the strings a builder receives, this is the locale the strings were
  /// resolved for.
  final Locale? locale;

  /// The units distances are shown in, when the field's `origin` is set.
  ///
  /// When `null`, the units follow the device's region: miles and feet in the
  /// United States, the United Kingdom, Liberia and Myanmar, kilometres and
  /// metres everywhere else. On web the region comes from the browser's
  /// language setting, which often has no region (`he` rather than `he-IL`);
  /// then the units are metric.
  ///
  /// In the strings a builder receives, this is always set: the units the
  /// widget uses.
  final PlacesDistanceUnits? distanceUnits;

  final String? _searchHint;
  final String? _loadingText;
  final String? _noResultsText;
  final String? _errorText;
  final String? _retryText;
  final String? _poweredByGoogleLabel;
  final String? _overlayTitle;
  final String? _closeLabel;
  final String? _clearLabel;
  final String? _placeSuggestionLabel;
  final String? _querySuggestionLabel;
  final String? _distanceUnitMeters;
  final String? _distanceUnitKilometers;
  final String? _distanceUnitMiles;
  final String? _distanceUnitFeet;
  final String? _selectionLoadingLabel;
  final String? _photoAttributionPrefix;
  final String? _viewOnGoogleMapsText;

  /// Placeholder text shown in the search field.
  String get searchHint => _searchHint ?? 'Search places';

  /// Text shown while suggestions are loading.
  String get loadingText => _loadingText ?? 'Loading places…';

  /// Text shown when no matching suggestions are returned.
  String get noResultsText => _noResultsText ?? 'No matching places found.';

  /// Generic error text shown when a request fails.
  String get errorText => _errorText ?? 'Unable to load places.';

  /// Label used for retry actions in error states.
  String get retryText => _retryText ?? 'Retry';

  /// Accessibility label used for the Google attribution image.
  String get poweredByGoogleLabel =>
      _poweredByGoogleLabel ?? 'Powered by Google';

  /// Title of the dialog and fullscreen search.
  ///
  /// The dialog shows it above the field. The fullscreen search puts the
  /// field in the top bar instead, so screen readers announce this as the
  /// screen's name.
  String get overlayTitle => _overlayTitle ?? 'Search places';

  /// Label for the control that closes the dialog or fullscreen search: the
  /// close button in the dialog, the back button in the fullscreen top bar.
  String get closeLabel => _closeLabel ?? 'Close';

  /// Tooltip/semantic label for the field clear button.
  String get clearLabel => _clearLabel ?? 'Clear search';

  /// Semantic label prefix for place suggestions.
  String get placeSuggestionLabel =>
      _placeSuggestionLabel ?? 'Place suggestion';

  /// Semantic label prefix for query suggestions.
  String get querySuggestionLabel =>
      _querySuggestionLabel ?? 'Query suggestion';

  /// Unit after a distance under 1 km, as in "850 m".
  ///
  /// Suggestions only carry a distance when [PlacesAutocompleteField.origin]
  /// is set.
  String get distanceUnitMeters => _distanceUnitMeters ?? 'm';

  /// Unit after a distance of 1 km or more, as in "1.2 km".
  String get distanceUnitKilometers => _distanceUnitKilometers ?? 'km';

  /// Unit after a distance shown in miles, as in "0.8 mi".
  String get distanceUnitMiles => _distanceUnitMiles ?? 'mi';

  /// Unit after a short distance shown in feet, as in "500 ft".
  String get distanceUnitFeet => _distanceUnitFeet ?? 'ft';

  /// Screen-reader label of the progress bar shown while a picked place's
  /// details load.
  String get selectionLoadingLabel =>
      _selectionLoadingLabel ?? 'Loading place details';

  /// Text placed before a photo's author names, as in "Photo by Ana Lima", by
  /// `PlacePhotoView` and `PlacesPhotoAttribution`.
  String get photoAttributionPrefix => _photoAttributionPrefix ?? 'Photo by';

  /// Text of the link that opens a photo on Google Maps, drawn after the
  /// author names by `PlacePhotoView` and `PlacesPhotoAttribution`.
  String get viewOnGoogleMapsText =>
      _viewOnGoogleMapsText ?? 'View on Google Maps';
}

/// Internal. The device's region, such as `US`, or `null` when it has none.
// ponytail: read on build, with no rebuild of its own; a region change with no
// locale change shows on the next rebuild. Listen for locale changes if that
// ever matters.
String? placesDeviceRegion() =>
    WidgetsBinding.instance.platformDispatcher.locale.countryCode;

/// Internal. [strings] as a widget under [context] shows them: every string
/// [strings] sets, and the bundle of its language for the rest.
///
/// The language is [PlacesStrings.locale], else the app's active locale. The
/// units are [PlacesStrings.distanceUnits], else the device region's.
PlacesStrings resolvePlacesStrings(
  BuildContext context,
  PlacesStrings strings,
) {
  // A subclass or implementation may override the getters, and has no
  // readable private fields: every string is taken from its getters, as
  // 0.7.x did.
  if (strings.runtimeType != PlacesStrings) {
    final custom = strings;
    strings = PlacesStrings(
      locale: custom.locale,
      distanceUnits: custom.distanceUnits,
      searchHint: custom.searchHint,
      loadingText: custom.loadingText,
      noResultsText: custom.noResultsText,
      errorText: custom.errorText,
      retryText: custom.retryText,
      poweredByGoogleLabel: custom.poweredByGoogleLabel,
      overlayTitle: custom.overlayTitle,
      closeLabel: custom.closeLabel,
      clearLabel: custom.clearLabel,
      placeSuggestionLabel: custom.placeSuggestionLabel,
      querySuggestionLabel: custom.querySuggestionLabel,
      distanceUnitMeters: custom.distanceUnitMeters,
      distanceUnitKilometers: custom.distanceUnitKilometers,
      distanceUnitMiles: custom.distanceUnitMiles,
      distanceUnitFeet: custom.distanceUnitFeet,
      selectionLoadingLabel: custom.selectionLoadingLabel,
      photoAttributionPrefix: custom.photoAttributionPrefix,
      viewOnGoogleMapsText: custom.viewOnGoogleMapsText,
    );
  }
  final locale = strings.locale ?? Localizations.maybeLocaleOf(context);
  final b = switch (locale?.languageCode) {
    'he' => placesStringsHe,
    'ar' => placesStringsAr,
    'ru' => placesStringsRu,
    'fr' => placesStringsFr,
    'de' => placesStringsDe,
    'es' => placesStringsEs,
    'pt' => placesStringsPt,
    _ => const PlacesStrings(),
  };
  return PlacesStrings(
    locale: locale,
    distanceUnits:
        strings.distanceUnits ??
        (placesRegionUsesImperial(placesDeviceRegion())
            ? PlacesDistanceUnits.imperial
            : PlacesDistanceUnits.metric),
    searchHint: strings._searchHint ?? b._searchHint,
    loadingText: strings._loadingText ?? b._loadingText,
    noResultsText: strings._noResultsText ?? b._noResultsText,
    errorText: strings._errorText ?? b._errorText,
    retryText: strings._retryText ?? b._retryText,
    poweredByGoogleLabel:
        strings._poweredByGoogleLabel ?? b._poweredByGoogleLabel,
    overlayTitle: strings._overlayTitle ?? b._overlayTitle,
    closeLabel: strings._closeLabel ?? b._closeLabel,
    clearLabel: strings._clearLabel ?? b._clearLabel,
    placeSuggestionLabel:
        strings._placeSuggestionLabel ?? b._placeSuggestionLabel,
    querySuggestionLabel:
        strings._querySuggestionLabel ?? b._querySuggestionLabel,
    distanceUnitMeters: strings._distanceUnitMeters ?? b._distanceUnitMeters,
    distanceUnitKilometers:
        strings._distanceUnitKilometers ?? b._distanceUnitKilometers,
    distanceUnitMiles: strings._distanceUnitMiles ?? b._distanceUnitMiles,
    distanceUnitFeet: strings._distanceUnitFeet ?? b._distanceUnitFeet,
    selectionLoadingLabel:
        strings._selectionLoadingLabel ?? b._selectionLoadingLabel,
    photoAttributionPrefix:
        strings._photoAttributionPrefix ?? b._photoAttributionPrefix,
    viewOnGoogleMapsText:
        strings._viewOnGoogleMapsText ?? b._viewOnGoogleMapsText,
  );
}
