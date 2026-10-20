# Recipes

Task-by-task guides for `google_places_sdk_flutter`, beyond the
[README](../README.md)'s quick start. Every option and default is in the
[API reference](api_reference.md).

- [Use the field inside a Form](#use-the-field-inside-a-form)
- [Search in a dialog or on a full screen](#search-in-a-dialog-or-on-a-full-screen)
- [Search without a widget](#search-without-a-widget)
- [Build your own autocomplete UI](#build-your-own-autocomplete-ui)
- [Show the distance from the user's location](#show-the-distance-from-the-users-location)
- [Display photo attribution](#display-photo-attribution)
- [Cancel work that is no longer needed](#cancel-work-that-is-no-longer-needed)
- [Secure proxy and platform identity](#secure-proxy-and-platform-identity)
- [Typed errors and HTTP ownership](#typed-errors-and-http-ownership)
- [Common widget options](#common-widget-options)

## Use the field inside a Form

`PlacesAutocompleteFormField` supports normal Flutter validation and reset
behavior:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: PlacesAutocompleteFormField(
    apiKey: apiKey,
    validator: (selection) =>
        selection == null ? 'Choose a place.' : null,
  ),
);

formKey.currentState!.reset();
```

It also takes `onSaved`, `initialValue`, `autovalidateMode`, `forceErrorText`,
`errorBuilder`, and `restorationId`, as other form fields do.

## Search in a dialog or on a full screen

`PlacesAutocompleteOverlay.show()` opens the search and returns the pick, or
`null` if the user dismisses it:

```dart
final selection = await PlacesAutocompleteOverlay.show(
  context,
  apiKey: apiKey,
  mode: PlacesAutocompleteOverlayMode.fullscreen,
);
```

`mode` defaults to `dialog`. To open the search from a field the user taps
instead, give the field a `fieldMode`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  fieldMode: PlacesAutocompleteFieldMode.dialog,
  onSelection: (selection) => debugPrint(selection.displayText),
)
```

Every search option on the field — `decoration`, `origin`, `selectionFields`,
and the rest — reaches the dialog and fullscreen search too.

## Search without a widget

`PlacesClient` makes the same calls the widgets make, plus Text Search, Nearby
Search, Place Photos, and Time Zone. Create one client, share it, and close it
when you are done:

```dart
final client = PlacesClient(apiKey: apiKey);

final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

for (final place in results) {
  debugPrint(place.displayName?.text);
}

await client.close();
```

Text Search and Nearby Search return `PlaceFieldPresets.minimal` by default —
a name, an address, and coordinates — and Place Details returns
`PlaceFieldPresets.address`. Pass `fields:` to ask for more.

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

When requesting a later page, keep every other value from the first request
unchanged.

## Build your own autocomplete UI

To render suggestions yourself and still be billed per session, reuse one
session token for the whole search and pass it to Place Details. End an
abandoned session explicitly:

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
  debugPrint(place.formattedAddress);
}
```

Use `autocompleteSuggestions()` with `includeQueryPredictions: true` when the
application also accepts suggested search phrases instead of only places.

## Show the distance from the user's location

Set `origin` and Google returns a distance for every suggestion, which the field
renders beside it:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
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

### Using the device's location as the origin

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

## Display photo attribution

Photos are not in the default fields: add `PlaceField.photos` to
`selectionFields` or `fields:`, or `place.photos` comes back empty. When a
returned photo includes authors, display Google's supplied attribution beside
the image:

```dart
PlacesPhotoAttribution(photo: photo)
```

`PlacePhoto.authors` is available when a custom attribution layout is needed.
Each `client.fetchPhotoMedia()` call is billed separately.

## Cancel work that is no longer needed

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
completion and reports a typed cancellation error. The widgets cancel their own
work when they are disposed.

## Secure proxy and platform identity

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

For a key restricted to your Android or iOS app, send the app's identity. A
client made from a widget's `apiKey:` cannot, so build one and pass it as
`client:`:

```dart
final client = PlacesClient(
  apiKey: apiKey,
  options: const PlacesClientOptions(
    applicationIdentity: PlacesApplicationIdentity.android(
      'com.example.app',
      'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
    ),
  ),
);
```

`PlacesApplicationIdentity.ios(bundleIdentifier)` is the iOS equivalent, and
`PlacesProxyConfiguration` can combine Maps JavaScript with a proxy fallback on
web. See [Security and transport configuration](security_and_transports.md) for
the setup guide, transport matrix, CSP options, and direct-fallback risks.

## Typed errors and HTTP ownership

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

The widgets pass the same errors to `onError`.

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

## Common widget options

The same names work on `PlacesAutocompleteField`, `PlacesAutocompleteFormField`,
and `PlacesAutocompleteOverlay.show()`. The
[API reference](api_reference.md#widget-defaults) lists every option.

| Option | Default | Use when |
| --- | --- | --- |
| `apiKey` / `client` | one required | The widget owns a client, or you share yours. |
| `fieldMode` | `inline` | You want inline, dialog, or fullscreen UI. |
| `languageCode` | `null` | You want localized Google results. |
| `regionCode` | `null` | You want region-aware ranking or formatting. |
| `includedRegionCodes` | empty | You only want results in some countries. |
| `includedPrimaryTypes` | empty | You want types such as `restaurant` or `(cities)`. |
| `locationBias` | `null` | You prefer results near an area. |
| `locationRestriction` | `null` | You only want results inside an area. |
| `origin` | `null` | You want a distance beside each suggestion. |
| `fetchPlaceDetailsOnSelection` | `true` | Set `false` when only the place ID is needed. |
| `selectionFields` | `address` | You need more than coordinates and an address. |
| `fetchTimeZoneOnSelection` | `false` | The selection needs Time Zone API data. |
| `includeQueryPredictions` | `false` | You also accept suggested search phrases. |
| `maxSuggestions` | `5` | You want fewer than Google's five suggestions. |
| `showPoweredByGoogle` | `true` | The package should render Google attribution. |

`locationBias` and `locationRestriction` cannot be used together. `fieldMode`
belongs to the field widgets; `show()` takes `mode` instead.
