# Google Places SDK Flutter

[![pub package](https://img.shields.io/pub/v/google_places_sdk_flutter.svg)](https://pub.dev/packages/google_places_sdk_flutter)
[![pub points](https://img.shields.io/pub/points/google_places_sdk_flutter)](https://pub.dev/packages/google_places_sdk_flutter/score)
[![likes](https://img.shields.io/pub/likes/google_places_sdk_flutter)](https://pub.dev/packages/google_places_sdk_flutter/score)
[![CI](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml)
[![License: BSD-3-Clause](https://img.shields.io/badge/license-BSD--3--Clause-blue.svg)](LICENSE)

Address autocomplete for Flutter on Google Places API (New): the user types, picks a place, and
your app gets its coordinates and a parsed address.

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/example.gif" alt="Package example" width="320" />
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

- [Quick start](#quick-start)
- [What you get back](#what-you-get-back)
- [Costs](#costs)
- [Security](#security)
- [Troubleshooting](#troubleshooting)
- [Common usage](#common-usage)
- [What's new](#whats-new)
- [Advanced usage](#advanced-usage)
- [Example app](#example-app)
- [More documentation](#more-documentation)

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

### Apps that still use `package:flutter/material.dart`

The widgets work there too, with no extra code. They use `material_ui`'s default theme, following
your app's light or dark brightness, and print a one-time note in debug builds. To style the field,
wrap it in `material_ui`'s `Theme`, or migrate the app with
`dart fix --apply --code=migrate_design_widgets` so it uses your app's own theme.

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
which is common in the UK. The place's name is `selection.suggestion.primaryText.text`.

By default the widgets request `PlaceFieldPresets.address`. Ask for more with `selectionFields`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  selectionFields: {...PlaceFieldPresets.address, PlaceField.photos},
)
```

## Costs

Google bills autocomplete [per session](https://developers.google.com/maps/documentation/places/web-service/session-pricing).
The widgets put each search in one session and end it with the Place Details request made when the
user picks a place. With the default `PlaceFieldPresets.address` that request is billed as Place
Details Essentials, Google's lowest tier that returns an address. Adding a Pro or Enterprise field
to `selectionFields` — `displayName`, `rating`, or anything in `PlaceFieldPresets.recommended` —
moves it to a higher tier. Typing is debounced (300 ms by default, set on
`PlacesAutocompleteController`). `fetchPlaceDetailsOnSelection: false` skips the details request,
but Google then bills each autocomplete request on its own, so it is not automatically cheaper.

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
| On web, nothing loads and the browser console shows `ApiNotActivatedMapError` or `RefererNotAllowedMapError` | Enable the **Maps JavaScript API**, and add your site to the key's website restrictions. |
| `REQUEST_DENIED` from a time-zone lookup | Enable the **Time Zone API** for the key, or turn off `fetchTimeZoneOnSelection`. |
| `place.photos` is always empty | Photos are not in the default fields. Add `PlaceField.photos` to `selectionFields`, as shown in [What you get back](#what-you-get-back). |
| `place.displayName` is `null` | It is a Pro field, not in the default. Use `selection.suggestion.primaryText.text`, or add `PlaceField.displayName`. |

## Common usage

### Use the field inside a Form

`PlacesAutocompleteFormField` supports normal Flutter validation and reset
behavior:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: PlacesAutocompleteFormField(
    client: client,
    validator: (selection) =>
        selection == null ? 'Choose a place.' : null,
  ),
);

formKey.currentState!.reset();
```

Use `PlacesAutocompleteOverlay.show()` when the search should open in a dialog
or fullscreen page instead of appearing inline.

### Search without a widget

The client also supports Place Details, Text Search, Nearby Search, Time Zone,
and Place Photos:

```dart
final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

for (final place in results) {
  debugPrint(place.displayName?.text);
}
```

Use `searchTextPage()` only when pagination metadata is needed:

```dart
final page = await client.searchTextPage(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

if (page.nextPageToken case final token?) {
  final nextPage = await client.searchTextPage(
    TextSearchRequest(
      textQuery: 'coffee near me',
      pageSize: 10,
      pageToken: token,
    ),
  );
  debugPrint('${nextPage.results.length} more places');
}
```

### Show the distance to each suggestion

Set `origin` and Google returns a distance for every suggestion, which the field
renders beside it:

```dart
PlacesAutocompleteField(
  client: client,
  origin: const PlaceCoordinates(latitude: 40.7580, longitude: -73.9855),
)
```

Two things to know before you use it:

- Distances are **straight-line**, not driving or walking distance. They will
  not match what a maps app shows for the same pair.
- `origin` only computes the number. It does not change which places are
  returned — use `locationBias` or `locationRestriction` for that.

Without `origin`, no distance is requested and none is rendered. That is the
default.

#### Using the device's location as the origin

**This package never requests location permission, and does not depend on any
location library.** Your app fetches the coordinates and passes them in. Any
package works; the example below uses
[`geolocator`](https://pub.dev/packages/geolocator).

Add the platform configuration first, or the request fails at runtime:

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show how far each place is from you.</string>
```

On web the browser prompts on its own, but the page must be served over HTTPS
(or `localhost`). macOS needs a location entitlement in both
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`. Desktop
support otherwise depends on the location package you choose, not on this one.

Then resolve the coordinates and hand them to the field:

```dart
class _SearchPageState extends State<SearchPage> {
  PlaceCoordinates? _origin;

  @override
  void initState() {
    super.initState();
    _loadOrigin();
  }

  Future<void> _loadOrigin() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _origin = PlaceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlacesAutocompleteField(client: widget.client, origin: _origin);
  }
}
```

Every early return leaves `_origin` as `null`, so search keeps working and
simply shows no distances. Denying permission degrades the feature rather than
breaking the field.

A first GPS fix can take several seconds. Resolving it in `initState` as above
means the field is usable immediately and distances appear once the fix lands —
do not block the search on it.

### Display photo attribution

When a returned photo includes authors, display Google's supplied attribution
beside the image:

```dart
PlacesPhotoAttribution(photo: photo)
```

`PlacePhoto.authors` is available when a custom attribution layout is needed.

## What's new

Version `0.7.0` moves the widget layer from `package:flutter/material.dart` to the standalone
[`material_ui`](https://pub.dev/packages/material_ui) package, and keeps it working in apps that have
not migrated. The widgets take an `apiKey:`, return coordinates and an address by default, and
`PlaceData` gains `city`, `streetAddress`, and other address getters. The supported floor rises to
Flutter `>=3.44.0` and Dart `>=3.12.0`. See [MIGRATION.md](MIGRATION.md#070) for the defaults that
changed.

Version `0.6.1` is a bug-fix release. Dialog and fullscreen modes now honor the
field's `decoration`, `suggestionBuilder`, `showPoweredByGoogle`, `onClearField`,
and `enabled`; Retry works on web; and the new `origin` option makes Google
return a distance for each suggestion, which the widget renders.

It also contains a security fix: photo media no longer sends the API key as a
URL query parameter. **Rotate any key used with `fetchPhotoMedia` on
`0.5.0`–`0.6.0`.**

Version `0.6.0` added Text Search pagination, cancellation, typed errors, richer
Place data, complete Form reset behavior, photo attribution helpers, and safer
proxy and web options. There are no public API removals or required source
migrations in either release. Text Search `maxResultCount`, string
`proxyBaseUrl`, and direct browser REST fallback are deprecated, with
replacements available now.

See [What's new in 0.7.0](doc/whats_new_0_7_0.md),
[What's new in 0.6.1](doc/whats_new_0_6_1.md), and
[What's new in 0.6.0](doc/whats_new_0_6_0.md) for examples, compatibility
notices, and the extended feature summaries.

## Advanced usage

The sections below are for applications that need headless autocomplete,
explicit cancellation, custom transports, or detailed error handling. The
quick-start widget manages these concerns automatically for normal use.

### Headless autocomplete sessions

Reuse one session token for a headless autocomplete flow and pass it to Place
Details. End abandoned sessions explicitly:

```dart
final sessionToken = AutocompleteSessionToken.generate();

final suggestions = await client.autocomplete(
  AutocompleteRequest(
    input: 'coffee',
    sessionToken: sessionToken,
  ),
);

if (suggestions.isEmpty) {
  await client.endAutocompleteSession(sessionToken);
} else {
  final place = await client.fetchPlace(
    PlaceDetailsRequest(
      placeId: suggestions.first.placeId,
      sessionToken: sessionToken,
    ),
  );
  debugPrint(place.displayName?.text);
}
```

Use `autocompleteSuggestions()` with `includeQueryPredictions: true` when the
application also accepts suggested search phrases instead of only places.

### Cancel work that is no longer needed

Every client operation accepts an optional cancellation token:

```dart
final cancellation = PlacesCancellationToken();

final request = client.searchText(
  const TextSearchRequest(textQuery: 'coffee'),
  cancellationToken: cancellation,
);

cancellation.cancel();
await request;
```

HTTP transports abort the request. Maps JavaScript safely ignores a late
completion and reports a typed cancellation error.

### Secure proxy and platform identity

Use a keyless authenticated proxy client when the application should not carry
a Google web-service key:

```dart
final client = PlacesClient.proxy(
  placesEndpoint: Uri.parse('https://api.example.com/maps/places/v1'),
  timeZoneEndpoint: Uri.parse('https://api.example.com/maps/timezone'),
  authentication: (_) async => <String, String>{
    'Authorization': 'Bearer ${await session.currentAccessToken()}',
  },
);
```

The proxy must authenticate clients, allowlist operations, enforce quotas, and
add its restricted Google credential server-side. The package never forwards a
Google key to configured proxy endpoints.

`PlacesProxyConfiguration` can combine Maps JavaScript with proxy fallback.
`PlacesApplicationIdentity.android()` and `.ios()` can add Google's documented
application identity headers for direct mobile REST calls.

See [Security and transport configuration](doc/security_and_transports.md) for
the setup guide, transport matrix, CSP options, and direct-fallback risks.

### Typed errors and HTTP ownership

All package-generated failures are `PlacesException` values:

```dart
try {
  await client.searchText(
    const TextSearchRequest(textQuery: 'coffee'),
  );
} on PlacesException catch (error) {
  debugPrint('${error.kind.name}: ${error.message}');
  if (error.retryable) {
    // Offer a retry action.
  }
}
```

An injected `http.Client` remains caller-owned by default. Transfer ownership
only when `PlacesClient.close()` should also close it:

```dart
final client = PlacesClient(
  apiKey: apiKey,
  httpClient: injectedClient,
  options: const PlacesClientOptions(
    httpClientOwnership: PlacesHttpClientOwnership.placesClient,
  ),
);
```

HTTP client injection is unsupported on web.

### Common options

| Option | Default | Use when |
| --- | --- | --- |
| `apiKey` / `client` | one required | The widget owns a client, or you share yours. |
| `fieldMode` | `inline` | You want inline, dialog, or fullscreen UI. |
| `languageCode` | `null` | You want localized Google results. |
| `regionCode` | `null` | You want region-aware ranking or formatting. |
| `locationBias` | `null` | You prefer results near an area. |
| `locationRestriction` | `null` | You only want results inside an area. |
| `includedPrimaryTypes` | empty | You want types such as `restaurant` or `(cities)`. |
| `fetchPlaceDetailsOnSelection` | `true` | Set `false` when only the place ID is needed. |
| `fetchTimeZoneOnSelection` | `false` | The selection needs Time Zone data. |
| `selectionFields` | `address` | You need more than coordinates and an address. |
| `includeQueryPredictions` | `false` | You also accept suggested search phrases. |
| `maxSuggestions` | `5` | You want fewer than Google's five suggestions. |
| `showPoweredByGoogle` | `true` | The package should render Google attribution. |

`locationBias` and `locationRestriction` cannot be used together.

## Example app

The [example application](example/README.md) demonstrates inline and Form
fields, dialog and fullscreen modes, locale and RTL behavior, Text Search
pagination, Place details, Time Zone data, and proxy configuration.

Run it with:

```shell
cd example
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

## More documentation

- [What's new in 0.7.0](doc/whats_new_0_7_0.md)
- [What's new in 0.6.1](doc/whats_new_0_6_1.md)
- [What's new in 0.6.0](doc/whats_new_0_6_0.md)
- [Migration guide](MIGRATION.md)
- [API reference and defaults](doc/api_reference.md)
- [Security and transport configuration](doc/security_and_transports.md)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service)
- [Place Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- [Place Details (New)](https://developers.google.com/maps/documentation/places/web-service/place-details)
- [Time Zone API](https://developers.google.com/maps/documentation/timezone/requests-timezone)
