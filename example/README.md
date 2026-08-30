# google_places_sdk_flutter example

This app demonstrates inline, Form/reset, dialog, and fullscreen autocomplete;
place and query suggestions; details and time-zone enrichment; localized RTL
UI; paged Text Search and the current stable Place resource fields; and the
suggestion distances and launcher-mode customization added in package version
`0.6.1`.

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

The advanced configuration section contains optional Place Details, Time Zone,
query-prediction, distance, and page-size controls. These are kept out of the
main flow so the simplest widget and Text Search examples remain easy to follow.

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
