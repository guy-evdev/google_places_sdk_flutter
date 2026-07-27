# What's new in 0.6.1

Version `0.6.1` is a bug-fix release. It contains one security fix, a group of
widget correctness fixes, and one small additive feature.

There are no deprecations, no public API removals, and no required source
migrations. Every existing call site keeps working.

## Security

### The API key no longer travels in the photo media URL

`fetchPhotoMedia` used to append `key=<your-api-key>` to the request URL, in
addition to the `X-Goog-Api-Key` header that already authenticated the call. The
credential was therefore sent twice, once in a place that proxy logs, CDN logs,
and browser history routinely record.

`0.6.1` removes the query parameter. Photo media now authenticates exactly like
every other operation, and a regression test asserts that no credential appears
in any request URI for any operation.

**If an application called `fetchPhotoMedia` on `0.5.0`–`0.6.0`, rotate that API
key.** The key may be present in logs owned by any intermediary that handled
those requests. See the
[security and transport guide](security_and_transports.md) for the full
credential posture.

The Google Time Zone API is the one remaining operation that keys the URL. It
has no header authentication, so this is unavoidable; it is asserted explicitly
in the test suite so the exception stays visible rather than becoming a habit.

## Fixes

### Dialog and fullscreen modes honor field customization

`PlacesAutocompleteField` forwarded most of its configuration to the dialog and
fullscreen launchers, but silently dropped five options: `decoration`,
`suggestionBuilder`, `showPoweredByGoogle`, `onClearField`, and `enabled`.
Setting `showPoweredByGoogle: false` had no effect in launcher modes, and custom
decoration and suggestion tiles were ignored.

All five now reach every mode, and `PlacesAutocompleteOverlay` accepts them
directly:

```dart
PlacesAutocompleteField(
  client: client,
  fieldMode: PlacesAutocompleteFieldMode.dialog,
  // Now visible in the dialog, not just on the launcher field.
  decoration: const InputDecoration(
    labelText: 'Delivery address',
    prefixIcon: Icon(Icons.place_outlined),
  ),
  showPoweredByGoogle: false,
)
```

A test now proves that every one of these options reaches inline, dialog, and
fullscreen. That is a standing rule for any option added from here on.

### Retry works on web

Tapping **Retry** in the error state moved focus to the button itself on web,
which the field interpreted as the user abandoning the search. The suggestion UI
closed and no retry was ever issued, so the button silently did nothing in a
browser. It now retries on every platform.

### The fullscreen overlay scrolls

Dialog mode wrapped its content in a scroll view; fullscreen mode did not. With
the keyboard up, five suggestions, and the attribution row, short viewports
overflowed. Fullscreen now scrolls the same way.

### Text Search no longer sends conflicting page-size fields

`TextSearchRequest.toRestJson()` emitted both `pageSize` and the deprecated
`maxResultCount` when both were set. The Maps JavaScript path already preferred
`pageSize`, so the same request behaved differently on REST and on web.

`maxResultCount` is now omitted whenever `pageSize` is set, on both paths. It is
still sent when `pageSize` is absent, and the deprecation stands until `1.0.0`.

### Reused cancellation tokens no longer accumulate listeners

A `PlacesCancellationToken` retained one closure per request issued against it,
so a long-lived token — the reuse pattern the documentation encourages — grew
without bound. Requests now detach their listener when they finish.

`PlacesCancellationToken.addCancellationListener` is public for the same reason:
it returns a function that detaches the listener, which `whenCancelled.then(...)`
cannot do.

### Smaller fixes

- `PlacePhoto.authors` is parsed once instead of on every read.
  `PlacesPhotoAttribution` reads it inside `build`, so it was re-allocating per
  frame.
- `Escape` closes the suggestion list.
- The field keeps focus and its decoration while a selection resolves, instead
  of disabling itself and flickering.
- A custom `timeZoneBaseUrl` keeps its own query parameters instead of having
  them discarded.
- The web REST-fallback trigger matches a wider set of Google error messages and
  is pinned by a regression test, so a Google reword fails CI instead of
  silently disabling the fallback for web users.

## Features

### `origin` and per-suggestion distances

The suggestion tile has always rendered a distance when Google returned one, but
`origin` — the request field that makes Google return it — was never exposed, so
the distance never appeared. It is now available on `PlacesAutocompleteField`,
`PlacesAutocompleteFormField`, and `PlacesAutocompleteOverlay`:

```dart
PlacesAutocompleteField(
  client: client,
  origin: const PlaceCoordinates(latitude: 40.7580, longitude: -73.9855),
  strings: const PlacesStrings(distanceUnitMeters: 'm'),
)
```

`origin` only asks Google to compute distances. It does not bias or restrict
which places come back — use `locationBias` or `locationRestriction` for that.

Distances render in meters exactly as Google returns them, with the unit taken
from the new `PlacesStrings.distanceUnitMeters`. Conversion to kilometers or
miles and locale-aware number formatting are planned for `0.8.0`.

Distances are **straight-line**, not driving or walking distance, so they will
not match what a maps app reports for the same pair.

`PlaceCoordinates` also gained `==`, `hashCode`, and `toString`. Without value
equality, rebuilding a widget with a freshly constructed `origin` would reset
the autocomplete billing session on every frame.

### Using the device's location as the origin

The common reason to set `origin` is "how far is this from me". **This package
never requests location permission and depends on no location library** — your
app resolves the coordinates and passes them in, using whichever package it
already has.

Add the platform configuration first. `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show how far each place is from you.</string>
```

On web the browser prompts on its own but the page must be served over HTTPS or
`localhost`; macOS needs a location entitlement in both `DebugProfile` and
`Release`. Desktop support beyond that depends on the location package you
choose, not on this one.

Then resolve once and hold the result in state:

```dart
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
```

Every early return leaves the origin `null`, so search keeps working with no
distances rather than failing. Resolve it up front rather than on the search
path — a first GPS fix can take several seconds, and autocomplete should never
wait on it.

The full walkthrough is in the
[README](../README.md#using-the-devices-location-as-the-origin). A built-in
resolver that owns the timing and caching for you is planned for a future version. the
package will still never acquire location itself.

## Notes

- `PlacesClient.testing` is documented as what it currently is: not usable from
  outside the package, because it requires an unexported internal type. A
  supported `PlacesTransport` extension point is planned for a future version. Until
  then, fake at the `http.Client` level.
- On web, `searchTextPage` always uses the HTTP/proxy route because Maps
  JavaScript does not expose pagination metadata. It therefore throws under
  `PlacesWebFallbackPolicy.disabled` even though `searchText` succeeds. This was
  already the behavior. it is now documented.
