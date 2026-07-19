# Google Places SDK Flutter

[![pub package](https://img.shields.io/pub/v/google_places_sdk_flutter.svg)](https://pub.dev/packages/google_places_sdk_flutter)
[![CI](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml)

A cross-platform Google Places client and autocomplete widget toolkit for
Flutter. Use the ready-made widget for a quick place picker, or use the typed
client APIs when the application needs more control.

## Contents

- [Preview](#preview)
- [Quick start](#quick-start)
- [Common usage](#common-usage)
- [What's new in 0.6.0](#whats-new-in-060)
- [Advanced usage](#advanced-usage)
- [Example app](#example-app)
- [More documentation](#more-documentation)

## Preview

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/example.gif" alt="Package example" width="320" />
</p>

## Quick start

Add the package:

```shell
flutter pub add google_places_sdk_flutter
```

Create a client and pass it to `PlacesAutocompleteField`:

```dart
import 'package:flutter/material.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

class PlacePicker extends StatefulWidget {
  const PlacePicker({super.key});

  @override
  State<PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends State<PlacePicker> {
  final _client = PlacesClient(
    apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
  );

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlacesAutocompleteField(
      client: _client,
      decoration: const InputDecoration(
        labelText: 'Choose a place',
        border: OutlineInputBorder(),
      ),
      onSelection: (selection) {
        debugPrint(selection.displayText);
      },
    );
  }
}
```

Pass the key when running the application:

```shell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

On web, the same client uses the Google Maps JavaScript Places library. Before
shipping, apply the correct Google API and application restrictions. REST-only
web operations should use the authenticated proxy described in the
[security guide](doc/security_and_transports.md).

## Common usage

### Load place details after selection

Enable details loading when the selection callback needs an address,
coordinates, or other Place data:

```dart
PlacesAutocompleteField(
  client: client,
  fetchPlaceDetailsOnSelection: true,
  selectionFields: PlaceFieldPresets.recommended,
  onSelection: (selection) {
    debugPrint(selection.place?.formattedAddress);
    debugPrint(selection.place?.location?.toString());
  },
)
```

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

### Display photo attribution

When a returned photo includes authors, display Google's supplied attribution
beside the image:

```dart
PlacesPhotoAttribution(photo: photo)
```

`PlacePhoto.authors` is available when a custom attribution layout is needed.

## What's new in 0.6.0

Version `0.6.0` adds Text Search pagination, cancellation, typed errors, richer
Place data, complete Form reset behavior, photo attribution helpers, and safer
proxy and web options.

There are no public API removals or required source migrations. Text Search
`maxResultCount`, string `proxyBaseUrl`, and direct browser REST fallback are
deprecated, with replacements available now.

See [What's new in 0.6.0](doc/whats_new_0_6_0.md) for deprecation examples,
compatibility notices, and the extended feature summary.

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
| `fieldMode` | `inline` | You want inline, dialog, or fullscreen UI. |
| `languageCode` | `null` | You want localized Google results. |
| `regionCode` | `null` | You want region-aware ranking or formatting. |
| `locationBias` | `null` | You prefer results near an area. |
| `locationRestriction` | `null` | You only want results inside an area. |
| `includedPrimaryTypes` | empty | You want types such as `restaurant` or `(cities)`. |
| `fetchPlaceDetailsOnSelection` | `false` | The selection needs full Place data. |
| `fetchTimeZoneOnSelection` | `false` | The selection needs Time Zone data. |
| `selectionFields` | `recommended` | You want to control the details payload. |
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

- [What's new in 0.6.0](doc/whats_new_0_6_0.md)
- [API reference and defaults](doc/api_reference.md)
- [Security and transport configuration](doc/security_and_transports.md)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service)
- [Place Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- [Place Details (New)](https://developers.google.com/maps/documentation/places/web-service/place-details)
- [Time Zone API](https://developers.google.com/maps/documentation/timezone/requests-timezone)
