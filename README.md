# Google Places SDK Flutter

[![pub package](https://img.shields.io/pub/v/google_places_sdk_flutter.svg)](https://pub.dev/packages/google_places_sdk_flutter)
[![pub points](https://img.shields.io/pub/points/google_places_sdk_flutter)](https://pub.dev/packages/google_places_sdk_flutter/score)
[![likes](https://img.shields.io/pub/likes/google_places_sdk_flutter)](https://pub.dev/packages/google_places_sdk_flutter/score)
[![CI](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

Address autocomplete for Flutter on Google Places API (New): the user types, picks a place, and
your app gets its coordinates and a parsed address.

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/example.gif" alt="Typing a place name, picking a suggestion and its details, then searching again in a dialog" width="320" />
</p>

Open a search and wait for the pick:

```dart
final selection = await PlacesAutocompleteOverlay.show(context, apiKey: 'YOUR_API_KEY');
final coordinates = selection?.place?.location;
final address = selection?.place?.formattedAddress;
```

Or put a search field on the page:

```dart
PlacesAutocompleteField(
  apiKey: 'YOUR_API_KEY',
  onSelection: (selection) => debugPrint(selection.place?.formattedAddress),
)
```

## When to use this package

- **One pick gives you coordinates and a parsed address** — street, city, postal code, country —
  at the lowest Place Details billing tier that returns an address.
- **Billing sessions are handled for you.** Each search and the pick that ends it are grouped into
  one Google autocomplete session, with no setup.
- **It works in any Flutter app**, whether it uses `material_ui` or still uses
  `package:flutter/material.dart`, with no extra code.
- **Pure Dart on Android, iOS, web (including Wasm), macOS, Windows, and Linux.** It is not a
  plugin, and its only runtime dependencies are `http`, `web`, and Flutter's own `material_ui`.
- **Your Google key can stay off the device** behind an authenticated proxy, and the package never
  asks for location permission.

Not a fit if your users need to pick a point on a map: this package searches by text.

## Contents

- [Ways to use it](#ways-to-use-it)
- [Quick start](#quick-start)
- [What you get back](#what-you-get-back)
- [Restricting results](#restricting-results)
- [Costs](#costs)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [What's new](#whats-new)
- [More documentation](#more-documentation)
- [Recipes](doc/recipes.md) — forms, dialogs, the widget's text, areas, search without a widget,
  and advanced setup

## Ways to use it

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/text_field_mode.png" alt="Suggestions in a card anchored to a search field" width="220" />
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/dialog_mode.png" alt="Search in a dialog" width="220" />
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/fullscreen_mode.png" alt="Search on a full screen" width="220" />
</p>

| You want | Use | Guide |
| --- | --- | --- |
| A search field on a page or in a form | `PlacesAutocompleteField`, `PlacesAutocompleteFormField` | [Quick start](#quick-start), [forms](doc/recipes.md#use-the-field-inside-a-form) |
| Search in a dialog or on a full screen, awaiting the pick | `PlacesAutocompleteOverlay.show()` | [Dialog and full screen](doc/recipes.md#search-in-a-dialog-or-on-a-full-screen) |
| Place data with no UI — details, Text Search, Nearby Search, photos, time zone | `PlacesClient` | [Search without a widget](doc/recipes.md#search-without-a-widget) |
| The widget, with your own field, rows, or styling | `fieldBuilder`, `suggestionItemBuilder`, `suggestionsViewBuilder` | [Customize](doc/recipes.md#customize-the-field-and-the-suggestions) |
| Your own search UI, still billed per session | `PlacesAutocompleteController` | [Your own autocomplete UI](doc/recipes.md#build-your-own-autocomplete-ui) |

Every option and default is in the [API reference](doc/api_reference.md).

## Quick start

Add the package:

```shell
flutter pub add google_places_sdk_flutter
```

In the [Google Cloud console](https://console.cloud.google.com/google/maps-apis), enable
**Places API (New)** — and, for web, the **Maps JavaScript API** — on a project with billing
enabled, and create an API key.

Pass the key to a widget. Reading it from `--dart-define` keeps it out of source control:

```dart
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

const apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

PlacesAutocompleteField(
  apiKey: apiKey,
  onSelection: (selection) {
    debugPrint(selection.displayText);
    debugPrint('${selection.place?.location}');
  },
)
```

```shell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

Given `apiKey:`, the widget creates its own `PlacesClient` and closes it when it is disposed. Pass
`client:` instead to share one client across screens, to use a key restricted to your Android or
iOS app (see [Security](#security)), or to use a keyless proxy.

The widget's own text — the hint, the loading and error messages — is English by default. Pass
`strings:` to [change or translate it](doc/recipes.md#change-or-translate-the-widgets-text).

### Apps that still use `package:flutter/material.dart`

The widgets work there too, with no extra code. They use `material_ui`'s default theme, following
your app's light or dark brightness, and print a one-time note in debug builds. To style the field,
wrap it in `material_ui`'s `Theme`; to keep your app's own theme, return your own `TextField` from
[`fieldBuilder`](doc/recipes.md#your-own-field-in-an-app-on-packagefluttermaterialdart), or migrate
the app with `dart fix --apply --code=migrate_design_widgets`.

Passing `decoration:` from such an app needs `material_ui`'s `InputDecoration`, imported with a
prefix — see [MIGRATION.md](MIGRATION.md#070).

## What you get back

`onSelection` receives a `PlaceSelection`. Its `place` holds the details:

```dart
final place = selection.place!;
place.location; // PlaceCoordinates(latitude: 40.71, longitude: -74.01)
place.formattedAddress; // 151 Broadway, New York, NY 10007, USA
place.streetAddress; // 151 Broadway
place.unit; // 4B
place.city; // New York
place.administrativeArea; // New York
place.postalCode; // 10007
place.country; // United States
place.countryShort; // US
```

`city` falls back to the postal town and other components for addresses that have no locality,
which is common in the UK. The place's name is `selection.suggestion.primaryText.text`. For an
address format the getters do not fit, `place.addressComponents` holds Google's parts as
`PlaceAddressComponent` values — see [the API reference](doc/api_reference.md#place-response-accessors).
To fill the rest of an address form from one pick, see [the recipe](doc/recipes.md#fill-an-address-form).

### Asking for more

`selectionFields` chooses what the details request returns. Google bills it at the tier of its most
expensive field:

| `selectionFields` | Returns | Highest field tier |
| --- | --- | --- |
| `PlaceFieldPresets.address` (default) | coordinates, the address, and its parsed parts | Essentials |
| `PlaceFieldPresets.recommended` | coordinates, the address, name, type, Maps link, icon, and rating — **not** the parsed parts | Enterprise |
| `PlaceFieldPresets.rich` | `recommended` plus the parsed parts, phone, website, opening hours, photos, reviews, and amenities | Enterprise + Atmosphere |
| Your own set of `PlaceField` values | exactly what you list, from all 80 fields | the highest among them |
| `PlaceFieldPresets.all` | every field — for exploring the data and for admin tools | Enterprise + Atmosphere, always |

`PlaceFieldPresets.all` is not for production;
[the API reference](doc/api_reference.md#place-field-presets) says why.

To keep the parsed address, add to the default rather than replacing it:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  selectionFields: {...PlaceFieldPresets.address, PlaceField.photos},
)
```

`PlaceField.photos` is an Essentials (IDs Only) field, so this pick stays at Essentials; fetching
each photo is billed separately. The [field table](doc/api_reference.md#place-field-presets) lists every field
with its tier, and [Costs](#costs) explains how the tier affects a session.

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/rich_result.png" alt="A place's details in the example app" width="220" />
</p>

### The place's time zone

Ask for it in the same details request:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  selectionFields: {...PlaceFieldPresets.address, PlaceField.timeZone},
  onSelection: (selection) => debugPrint(selection.place?.timeZone?.id), // America/New_York
)
```

or from Google's Time Zone API:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  fetchTimeZoneOnSelection: true,
  onSelection: (selection) => debugPrint(selection.timeZone?.timeZoneName), // Eastern Daylight Time
)
```

`PlaceField.timeZone` needs no second API, but it is a Pro field, so the details request is no
longer Essentials — see [Costs](#costs). `fetchTimeZoneOnSelection` leaves the details request as
it is and makes a second request to the Time Zone API, which is billed separately and must be
enabled for the key. It also returns the offset at a given moment, including daylight saving; set
the moment with `selectionTimeZoneAt`. [The recipe](doc/recipes.md#get-a-places-time-zone) shows
what each way returns.

### Photos

Add `PlaceField.photos` to `selectionFields`, then show one with `PlacePhotoView`:

```dart
// import 'package:url_launcher/url_launcher.dart';
PlacePhotoView(
  photo: place.photos.first,
  apiKey: apiKey,
  height: 200,
  onOpenLink: (uri) => launchUrl(uri),
)
```

It fetches the image at that size and draws the author's name and a "View on Google Maps" link
over it. Google requires that link. On web it opens in a new tab by itself. On Android, iOS,
macOS, Windows and Linux the package cannot open a link without a plugin, so **`onOpenLink` is
what shows the link there** — here with `url_launcher`, added to your app. Without it the link is
not shown.

Each photo shown is one billed Place Photos request. On web the lookup is a REST call, so with
`apiKey:` the key is sent from the browser; pass a proxy `client:` to avoid that.
[The recipe](doc/recipes.md#show-place-photos) covers strips, galleries, and your own look.

## Restricting results

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  includedRegionCodes: const ['us', 'ca'],
  includedPrimaryTypes: PlaceTypePresets.cities,
  languageCode: 'fr',
)
```

- `includedRegionCodes` — only places in these countries, as CLDR region codes.
- `includedPrimaryTypes` — only these [place types](https://developers.google.com/maps/documentation/places/web-service/place-types),
  such as `restaurant`. `PlaceTypePresets` has `cities`, `regions`, `postalCode`, `address` (precise
  addresses), and `establishment`.
- `locationBias` prefers an area; `locationRestriction` only returns places inside it. Use one, not
  both. Each takes a circle or a rectangle.
- `languageCode` — the language of the results; `regionCode` adjusts ranking and formatting.
- `origin` — not a filter: Google returns the straight-line distance to each suggestion and the field
  shows it. See [the recipe](doc/recipes.md#show-the-distance-from-the-users-location) for using the
  device's location.

To prefer places near a point:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  locationBias: LocationBias.circle(
    center: const PlaceCoordinates(latitude: 51.5074, longitude: -0.1278),
    radiusMeters: 20000,
  ),
)
```

[Limit results to an area](doc/recipes.md#limit-results-to-an-area) covers rectangles, restriction,
and which shapes each call accepts — through Maps JavaScript, the web default, `locationRestriction`
must be a rectangle.

All of them are listed with their defaults in the
[API reference](doc/api_reference.md#widget-defaults).

## Costs

Google bills autocomplete [per session](https://developers.google.com/maps/documentation/places/web-service/session-pricing).
The widgets put each search in one session and end it with the Place Details request made when the
user picks a place. With the default `PlaceFieldPresets.address`, a session bills its first 12
autocomplete requests and one Place Details Essentials request — the lowest tier that returns an
address. One Pro or Enterprise field in `selectionFields` — `displayName`, `timeZone`, `rating`, or
anything in `PlaceFieldPresets.recommended` — changes that: Google then bills the details request at
Enterprise + Atmosphere, and the session's autocomplete requests are free.

Two options send fewer autocomplete requests: `debounceDuration`, how long the field waits after
the last keystroke (300 ms by default), and `minInputLength`, the characters needed before it
searches at all (1 by default). `fetchPlaceDetailsOnSelection: false` skips the details request,
but Google then bills each autocomplete request on its own, so it is not automatically cheaper.
`PlacesClient`'s own calls bill the fields they request: Place Details defaults to
`PlaceFieldPresets.address`, Text Search and Nearby Search to `PlaceFieldPresets.minimal`. The
[field table](doc/api_reference.md#place-field-presets) gives each field's tier.

## Security

A Google key shipped in an app can be extracted from it. Restrict every key, and pick the setup
that fits:

| Setup | Key in the app | Use when |
| --- | --- | --- |
| Key restricted to your Android or iOS app, with `PlacesApplicationIdentity` | Yes, usable only by your app | A mobile app calling Google directly |
| Key restricted to your website, for the Maps JavaScript API | Yes, usable only from your domains | Autocomplete and details on web |
| `PlacesClient.proxy()` to your own authenticated server | **No** | The key must never ship, or you need per-user quotas |

An app-restricted mobile key needs `PlacesClientOptions.applicationIdentity`, so pass a `client:`
built with it rather than `apiKey:`. The [security guide](doc/security_and_transports.md) has the
setup for each row.

## Troubleshooting

The widget shows a short error message. Pass `onError: (error) => debugPrint('$error')` to see the
`PlacesException`, which carries Google's own explanation.

| Symptom | Fix |
| --- | --- |
| `HTTP 403, PERMISSION_DENIED`: "Places API (New) has not been used in project…" | Enable **Places API (New)** for the key's project. The legacy Places API is a different API and cannot be enabled on new projects. |
| `HTTP 403, PERMISSION_DENIED` mentioning billing | Enable billing on the Google Cloud project. |
| `HTTP 403, PERMISSION_DENIED`: "Requests from this Android client application…" or "…iOS client application… are blocked" | The key is restricted to your app but the request carried no identity. Pass a `client:` with `PlacesClientOptions.applicationIdentity` — see [Security](#security). |
| On web, including `--wasm` builds, nothing loads and the browser console shows `ApiNotActivatedMapError` or `RefererNotAllowedMapError` | Enable the **Maps JavaScript API**, and add your site to the key's website restrictions. Wasm builds use it from `0.7.0` on. |
| `REQUEST_DENIED` from a time-zone lookup | Enable the **Time Zone API** for the key, or turn off `fetchTimeZoneOnSelection`. |
| `place.photos` is always empty | Photos are not in the default fields. Add `PlaceField.photos` to `selectionFields`, as shown in [Photos](#photos). |
| `place.displayName` is `null` | It is a Pro field, not in the default. Use `selection.suggestion.primaryText.text`, or add `PlaceField.displayName`. |

## What's new

Version `0.7.0` moves the widget layer from `package:flutter/material.dart` to the standalone
[`material_ui`](https://pub.dev/packages/material_ui) package, and keeps it working in apps that have
not migrated. The widgets take an `apiKey:`, return coordinates and an address by default, and
`PlaceData` gains `city`, `streetAddress`, and other address getters. Inline suggestions float
over the page instead of pushing it down, and the fullscreen search puts the field in the top bar.
Three builders let you supply the field, each row, or the whole suggestion area.
`minInputLength` and `debounceDuration` send fewer billed requests, and the widgets take
`TextField`'s own options, such as `keyboardType` and `inputFormatters`.
`PlacePhotoView` shows a place's photos with their required attribution.
`PlacesClient` requests fewer fields by default. See [What's new in 0.7.0](doc/whats_new_0_7_0.md)
for details and examples, and [MIGRATION.md](MIGRATION.md#070) for the defaults that changed.

Earlier releases: [What's new in 0.6.1](doc/whats_new_0_6_1.md) and
[What's new in 0.6.0](doc/whats_new_0_6_0.md).

## More documentation

- [Recipes](doc/recipes.md) — forms, dialogs, search without a widget, your own UI, distances,
  photos, proxies, errors
- [API reference and defaults](doc/api_reference.md)
- [Generated API docs](https://pub.dev/documentation/google_places_sdk_flutter/latest/) — every
  class and member
- [Example app](example/README.md) — run it with
  `flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here` from `example/`
- [What's new in 0.7.0](doc/whats_new_0_7_0.md)
- [What's new in 0.6.1](doc/whats_new_0_6_1.md)
- [What's new in 0.6.0](doc/whats_new_0_6_0.md)
- [Migration guide](MIGRATION.md)
- [Security and transport configuration](doc/security_and_transports.md)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service)
- [Place Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- [Place Details (New)](https://developers.google.com/maps/documentation/places/web-service/place-details)
- [Time Zone API](https://developers.google.com/maps/documentation/timezone/requests-timezone)
