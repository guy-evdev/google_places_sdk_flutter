## 0.7.0

**Breaking changes:**

* Widgets now use [`material_ui`](https://pub.dev/packages/material_ui); build any `decoration:` from it. See [Migrating to 0.7.0](MIGRATION.md#070).
* Requires Flutter `>=3.44.0` and Dart `>=3.12.0`, `material_ui`'s minimum.
* `fetchPlaceDetailsOnSelection` now defaults to `true`, and `selectionFields` to the new Essentials-tier `PlaceFieldPresets.address`.
* `PlacesAutocompleteField.client` and `PlacesAutocompleteOverlay.client` are now nullable.
* `PlacesClient` requests fewer fields by default: `PlaceFieldPresets.address` for details, `PlaceFieldPresets.minimal` for Text Search and Nearby Search.
* Inline suggestions float over the page instead of pushing the content below the field down, opening above the field when the keyboard leaves more room there.
* The field's keyboard defaults to `TextInputType.streetAddress`: an address keyboard on Android, word capitalization on Linux.
* `PlacesAutocompleteController.selectedSelection` is read-only; use `setSelection`, `restoreSelection`, or `clearSelection`.

**New:**

* `apiKey:` on the autocomplete widgets and on `PlacesAutocompleteOverlay.show()`.
* Works in apps still on `package:flutter/material.dart`, with no extra code.
* Address getters: `city`, `streetAddress`, `county`, `neighborhood`, `unit`, `postalCodeSuffix`.
* Dialog and fullscreen search keep the field in place and scroll only the results; fullscreen puts the field in the top bar.
* `fieldBuilder`, `suggestionItemBuilder`, and `suggestionsViewBuilder` build the field, each row, and the suggestion area; the view gets the typed `PlacesException` when a search fails.
* `minInputLength` and `debounceDuration` on the widgets, to send fewer billed autocomplete requests.
* Every `TextField` option that fits an autocomplete field, on the widgets — `keyboardType`, `inputFormatters`, `onSubmitted`, the cursor and spell-check options, and more.
* `suggestionsViewOpenDirection` and `unfocusOnSelection` for inline fields, and `includeFutureOpeningBusinesses` on the widgets.
* `PlacesAutocompleteController` runs the search for your own UI — `search()`, `select()`, `retry()`, and its `suggestions`, `status`, and `error`, notifying its listeners as they change — and takes your own `TextEditingController` and `FocusNode`.
* `PlaceSelection.fromPlace` starts a form field from a saved place.
* `PlaceField.entrances` and `PlaceField.navigationPoints`, and `PlaceFieldPresets.all` with every field — for exploration, as it always bills at the highest tier.

**Fixed:**

* The first keystrokes no longer flash "No matching places found." before any response.
* The keyboard-highlighted row has a background, keeps its text colours, and scrolls into view.
* A `Theme` around the field now reaches the fullscreen search, as it already reached the dialog.
* On web, a circle `locationRestriction` for autocomplete through Maps JavaScript now fails with a `validation` error instead of being sent to an API that does not accept it.
* In `PlacesAutocompleteFormField`, typing after picking a place no longer clears the field.
* Rebuilding a widget with an equal `LocationBias` or `LocationRestriction`, or with new selection settings, no longer ends the user's search and billing session.

**Deprecated:**

* `suggestionBuilder` — use `suggestionItemBuilder`. Removed in `1.0.0`.

**Compatibility:**

* Wider dependency ranges: `http: ^1.5.0`, `web: ^1.0.0`; new `material_ui: ^1.0.0`.

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
