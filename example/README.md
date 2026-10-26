# google_places_sdk_flutter example

This app demonstrates the package's widgets in every mode — inline, in a `Form`
with reset, in a dialog, and fullscreen — with place and query suggestions, the
coordinates and parsed address a pick returns, place photos, time-zone lookups,
suggestion distances, custom suggestion rows, a right-to-left UI, and paged
Text Search.

As of package version `0.7.0` the app is built on
[`material_ui`](https://pub.dev/packages/material_ui) rather than
`package:flutter/material.dart`, and its localization delegates come from
`GlobalMaterialLocalizations.delegates`. It requires Flutter `>=3.44.0` and Dart `>=3.12.0`.

Run it with a Google Maps Platform key:

```shell
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your-key
```

Or run the keyless proxy path:

```shell
flutter run \
  --dart-define=PLACES_PROXY_URL=https://api.example.com/maps/places/v1 \
  --dart-define=PLACES_PROXY_TIME_ZONE_URL=https://api.example.com/maps/timezone \
  --dart-define=PLACES_PROXY_ACCESS_TOKEN=development-token
```

The static access token is only an example-app convenience. Production apps
should obtain a short-lived user/app token at runtime. The proxy must verify it
and add the Google credential server-side. See the package
[security and transport guide](../doc/security_and_transports.md).

## Using the demo

The main page starts with a compact summary of the active options. Select
**Configuration** to change the language, autocomplete widget, or Text Search
mode. Apply commits the draft; Cancel or dismissing the sheet leaves the active
demo unchanged.

Enter any query in **Text Search** and press Search. Single-page mode uses
`searchText()` and returns a simple list. Paged mode uses `searchTextPage()`,
shows response metadata, and adds **Load more** while Google returns a
`nextPageToken`. The configured page size is preserved for every page. Use the
clear action inside the query field to remove both the query and its results.

Every widget mode uses the same `decoration`, so switching between Text Field,
Dialog, and Fullscreen shows the label and prefix icon in all three. Before
`0.6.1` the dialog and fullscreen launchers silently dropped it.

The advanced configuration section turns Place Details (on by default, as in
the package), Time Zone, query predictions, distances, photos, and custom
suggestion rows on and off, and sets the Text Search page size. These are kept
out of the main flow so the simplest widget and Text Search examples remain
easy to follow.

After a pick, the **Coordinates and address** card lists the place's location
and the address getters the README's "What you get back" shows: `streetAddress`,
`unit`, `city`, `administrativeArea`, `postalCode`, `country`, and
`countryShort`.

**Show place photos** (on by default) adds `PlaceField.photos` to the details
request and shows the photos in a strip of `PlacePhotoView`s. Each photo shown
is one billed Place Photos request. The strip passes
`onOpenLink: (uri) => launchUrl(uri)`, which is why the example — and only the
example — depends on `url_launcher`: on mobile and desktop it is what opens the
"View on Google Maps" link Google requires. The package itself takes no plugin
dependency.

**Custom suggestion rows** builds each suggestion with `suggestionItemBuilder`,
in every mode, and under an inline field shows the field controller's `status`
— loading, results, empty, or error — as it changes.

**Show distance from an origin** sends `origin` with each autocomplete request,
so Google returns a distance for every suggestion and the widget renders it. The
demo uses a fixed coordinate to avoid a location permission; a real app would
pass the device's current position. The unit comes from
`PlacesStrings.distanceUnitMeters` and is localized per demo language.

Paged Text Search uses the package's HTTP/proxy route on web; see the package
[0.6.0 extended release notes](../doc/whats_new_0_6_0.md) for the transport
note.

Select **Form** to validate a required `PlaceSelection` and exercise
`FormState.reset()` with an external `PlacesAutocompleteController`.

The selection details card requests and displays typed opening dates, Google
Maps links, price ranges, embedded Place time zones, attributions, and transit
station data. These fields are opt-in so applications can keep their own field
masks and billing payloads narrow.

After a place is selected, the app also confirms that
`PlaceSelection.sessionToken` was preserved. It intentionally does not display
the token value. The package widgets manage selection and abandonment cleanup
automatically.

The client also demonstrates `PlacesClientOptions.requestTimeout`. Errors are
rendered using the safe `PlacesException.kind`, `operation`, `code`, and
`retryable` fields rather than raw request or credential data.
