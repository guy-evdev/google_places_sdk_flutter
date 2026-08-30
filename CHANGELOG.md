## 0.7.0

**Breaking changes:**

* The widget layer now uses [`material_ui`](https://pub.dev/packages/material_ui) instead of
  `package:flutter/material.dart`. `InputDecoration` on `PlacesAutocompleteField`,
  `PlacesAutocompleteOverlay`, `PlacesAutocompleteOverlay.show()`, and
  `PlacesAutocompleteFormField` now resolves to `material_ui`'s type. Apps must migrate in the
  same step — see [Migrating to 0.7.0](MIGRATION.md#070).
* The supported floor is now Flutter `>=3.44.0` and Dart `>=3.12.0`, up from Flutter `>=3.35.0`
  and Dart `>=3.9.0`. This is `material_ui`'s own minimum.

**Compatibility:**

* `material_ui: ^1.1.0` is a new direct dependency. `cupertino_ui` arrives transitively and needs
  no constraint of its own.
* No parameter was renamed or removed, no default changed, and no behaviour changed. This release
  contains nothing but the migration.

See [What's new in 0.7.0](doc/whats_new_0_7_0.md) for details and examples.

## 0.6.1

### July 27, 2026

**Security:**
  * Photo media no longer sends the API key as a URL query
    parameter. It authenticates with the `X-Goog-Api-Key` header like every other
    operation. Rotate any key used with `fetchPhotoMedia` on `0.5.0`–`0.6.0`.

**New:** 

* `origin` on the autocomplete widgets, which enables the per-suggestion
  distance display, plus `PlacesStrings.distanceUnitMeters`. Includes a
  device-location recipe covering the Android and iOS setup. The package itself
  never requests location permission.

**Fixed:**
* Dialog and fullscreen modes now honor `decoration`,
  `suggestionBuilder`, `showPoweredByGoogle`, `onClearField`, and `enabled`.
* The fullscreen overlay scrolls. 
* Retry works on web. 
* Text Search no longer sends `pageSize` and `maxResultCount` together.
* Reused cancellation tokens no longer accumulate listeners.

See [What's new in 0.6.1](doc/whats_new_0_6_1.md) for details and examples.

## 0.6.0

### July 20, 2026

**Deprecated:** 
* Text Search `maxResultCount` (use `pageSize`), string
  `proxyBaseUrl` (use typed proxy configuration), and direct browser REST
  fallback. Planned removal or default change: `1.0.0`.

**New:** 
* Text Search pagination, cancellation, richer Place data, photo
  attribution, typed errors, validation, and secure transport options.

**Fixed:** 
* Autocomplete billing sessions, stale async work, Form behavior,
  response handling, and diagnostic redaction.

**Compatibility:** 
* Proxy requests no longer receive Google keys. 
* Injected HTTP clients remain caller-owned unless ownership is transferred.

See [What's new in 0.6.0](doc/whats_new_0_6_0.md) for examples, behavior notes,
and complete details.

## 0.5.0

### June 3, 2026
- Added mixed autocomplete suggestions with opt-in query prediction support.
- Added Place Photos (New) media lookup through `fetchPhotoMedia`.
- Added newer Places API field masks for address descriptors, EV charging,
  fuel options, generative summaries, service-area businesses, and moved places.
- Improved autocomplete widget clear-button behavior, selection loading
  feedback, keyboard navigation, semantic labels, and text match highlighting.
- Enabled stricter analyzer settings and expanded Flutter 3.44 CI coverage.
- Compacted the README and added a dedicated API reference document.

## 0.4.2

### April 17, 2026
- Updated Dart docs, README media, and package screenshots.

## 0.4.1

### April 16, 2026
- Updated README preview images.

## 0.4.0

### April 16, 2026
  Initial public release on pub.dev.
- Added a cross-platform Google Places API (New) client for Flutter.
- Added inline, dialog, and fullscreen autocomplete widgets.
- Added optional place-details and time-zone fetching on selection.
- Added typed address support with structured models and convenience getters.
- Added Android, iOS, web, macOS, Windows, and Linux example support.
