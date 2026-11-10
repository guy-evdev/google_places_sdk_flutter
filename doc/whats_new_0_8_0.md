# What's new in 0.8.0

`0.8.0` makes the widgets speak your users' language. The search hint, the loading and error
messages, the dialog and fullscreen titles, the screen-reader labels and the photo attribution all
follow the app's language, and distances read in kilometres or miles. Most apps need no code and no
source change to upgrade.

- [The widgets follow the app's language](#the-widgets-follow-the-apps-language)
- [Show another language](#show-another-language)
- [Change one string](#change-one-string)
- [Distance units and formats](#distance-units-and-formats)
- [Distances in custom rows](#distances-in-custom-rows)
- [Portuguese](#portuguese)
- [The result language is separate](#the-result-language-is-separate)
- [Fixes](#fixes)
- [Compatibility notes](#compatibility-notes)

## The widgets follow the app's language

Eight languages are bundled: English, Hebrew, Arabic, Russian, French, German, Spanish and
Portuguese. The widgets use the `Locale` your app resolved, so if the language is in your
`supportedLocales` there is nothing to write:

```dart
PlacesAutocompleteField(apiKey: apiKey)
```

A regional locale uses its language (`fr-CA` gets French). Any other language gets English. Hebrew
and Arabic lay out right-to-left because your app does. The photo widgets and the dialog and
fullscreen search follow the same rule.

## Show another language

To show the widgets in a language other than the app's, set `PlacesStrings.locale`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  strings: const PlacesStrings(locale: Locale('he')),
)
```

## Change one string

A string you set replaces only that string. Everything you leave out stays in the widgets'
language, so in a Hebrew app this changes the hint and keeps the rest Hebrew:

```dart
strings: const PlacesStrings(searchHint: 'חפשו מסעדה')
```

Four strings are new: `distanceUnitKilometers`, `distanceUnitMiles`, `distanceUnitFeet`, and
`selectionLoadingLabel`, the screen-reader label of the progress bar shown while a picked place's
details load. `distanceUnitMeters` is now only the unit under 1 km.

## Distance units and formats

With `origin` set, each suggestion shows a distance. The units follow the device's region; the
number follows the language.

| Device region | Examples |
| --- | --- |
| US, GB, LR, MM | "500 ft", "0.8 mi", "12 mi" |
| Everywhere else | "850 m", "1.2 km", "12 km" |

Numbers use the language's decimal separator and digits: "1,2 km" in German, and Arabic-Indic digits
in Arabic regions that use them. On web, the region comes from the browser's language setting, which
often has none (`he` rather than `he-IL`); then distances are metric. To force one system:

```dart
strings: const PlacesStrings(distanceUnits: PlacesDistanceUnits.imperial)
```

This is a locale setting. The package still never asks for the device's location.

## Distances in custom rows

A row you build with `suggestionItemBuilder` gets the distance exactly as the default row shows it:

```dart
suggestionItemBuilder: (context, item) => ListTile(
  title: Text(switch (item.suggestion) {
    final PlaceSuggestion p => p.primaryText.text,
    final QuerySuggestion q => q.displayText,
  }),
  trailing: item.distanceText == null ? null : Text(item.distanceText!),
  onTap: item.onSelected,
),
```

`distanceText` is `null` when the field has no `origin`, and for a `QuerySuggestion`.

## Portuguese

The Portuguese bundle uses Brazilian wording. A European Portuguese app can override the two strings
that differ, only when its locale is `pt-PT`:

```dart
strings: Localizations.localeOf(context) == const Locale('pt', 'PT')
    ? const PlacesStrings(
        loadingText: 'A carregar locais…',
        selectionLoadingLabel: 'A carregar detalhes do local',
      )
    : const PlacesStrings(),
```

## The result language is separate

`PlacesStrings` is the widgets' own text. The language of the place names and addresses Google
returns is `languageCode`, and it is unchanged:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  languageCode: 'he',
  strings: const PlacesStrings(locale: Locale('he')),
)
```

## Fixes

- The fullscreen search field's end margin was 8 and is now 16, the same as the start.
- A long error or retry text no longer squeezes the error row; the retry button moves under the
  message.
- The photo attribution band is darker under high contrast (`MediaQuery.highContrast`), so the text
  stays legible.

## Compatibility notes

No source change is required, so there is no migration guide. Behaviour changes that can show up in
an app:

- **Distances are formatted.** Before, an app that set `origin` showed Google's number in metres:

  ```text
  0.7.x:  1234 m
  0.8.0:  1.2 km       (or 0.8 mi / 500 ft on US, GB, LR and MM devices)
  ```

- **Non-English apps get translated defaults.** Before, every default was English. To keep English,
  set `PlacesStrings(locale: Locale('en'))`.
- **A partial override fills the rest from the app's language.** Before, `PlacesStrings(searchHint:
  'x')` left every other string in English; now they follow the app.
- **`implements PlacesStrings`.** A class that implements it must add `locale`, `distanceUnits` and the four new
  string getters. Code that only creates, reads or extends `PlacesStrings` keeps working as in `0.7.x`.

There is no new dependency: number formatting uses locale data inside the package, not `intl`.
