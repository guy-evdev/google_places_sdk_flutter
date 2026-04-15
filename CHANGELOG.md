## 0.3.2 - 2026-04-15

- Fixed dialog sizing so autocomplete overlays shrink-wrap content more naturally instead of expanding to near fullscreen in some host app layouts.
- Exposed `maxSuggestions` through dialog and fullscreen overlay flows and aligned its behavior with Google Autocomplete (New) limits.
- Documented and clamped `maxSuggestions` to the upstream maximum of five predictions.
- Corrected the Powered by Google attribution asset theme mapping.

## 0.3.1 - 2026-04-15

- Fixed fullscreen overlay presentation so it uses the root navigator and opens truly fullscreen inside nested navigator setups such as `go_router` shells.
- Fixed dialog selection dismissal so it closes the dialog route instead of popping the underlying page.
- Improved dialog overlay layout constraints and route teardown stability.

## 0.3.0 - 2026-04-15

- Added typed address support through `PlacePostalAddress` and `PlaceAddressComponent`.
- Added `PlaceField.postalAddress` and included typed address data in the rich field preset.
- Added convenience getters on `PlaceData` for common address parts such as route, street number, locality, administrative area, postal code, country, and their short-text variants.
- Updated the example app and README to demonstrate the new typed address accessors.

## 0.2.0 - 2026-04-15

- Added Google Time Zone API support through `PlacesClient` and widget selection enrichment.
- Added standalone place-id and time-zone fetch helpers for non-widget flows.
- Extended `PlaceSelection` to optionally include resolved time-zone data.
- Updated the example app and README to cover the new place and time-zone APIs.

## 0.1.0 - 2026-04-14

- Initial clean-break release built on Places API (New).
- Added custom Flutter autocomplete widgets with package-owned models.
- Added web support through Google Maps JavaScript Places data APIs.
- Added a multi-platform example app with modern iOS `UIScene` lifecycle.
