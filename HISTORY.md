## 0.3.3 - 2026-04-16

- Added web fallbacks for place details and search requests when the Maps JavaScript Places library rejects richer field sets.
- Fixed Chrome/web parsing and initialization issues in the Places JavaScript backend.
- Preserved `proxyBaseUrl` behavior for web fallback requests.

## 0.3.2 - 2026-04-16

- Fixed dialog sizing so overlay content shrink-wraps more naturally.
- Fixed overlay `maxSuggestions` wiring for dialog and fullscreen modes.
- Documented and enforced Google Autocomplete's effective five-suggestion limit.
- Corrected the Powered by Google asset theme mapping.

## 0.3.1 - 2026-04-16

- Fixed fullscreen overlay presentation to use the root navigator inside nested navigation shells.
- Fixed dialog selection dismissal so it closes the dialog instead of popping the underlying route.
- Improved dialog overlay teardown stability.

## 0.3.0 - 2026-04-16

- Added typed `postalAddress` and `addressComponents` support.
- Added typed long-form and short-form address convenience getters on `PlaceData`.

## 0.2.0 - 2026-04-16

- Added Google Time Zone API support.
- Added standalone place fetching by place ID and standalone time-zone fetching APIs.
- Added selection enrichment with timezone data across widgets.

## 0.1.0 - 2026-04-16

- Initial clean-break rebuild on Places API (New).
- Added cross-platform client and widget support for Android, iOS, web, macOS, Windows, and Linux.
- Added inline, dialog, and fullscreen autocomplete experiences.
