# API Reference

Detailed defaults and field-mask preset reference for
`google_places_sdk_flutter`. For task-by-task guides, see [Recipes](recipes.md).

## Contents

- [Widget Defaults](#widget-defaults)
- [Client and Request Defaults](#client-and-request-defaults)
- [Autocomplete Sessions](#autocomplete-sessions)
- [Errors, Validation, and Ownership](#errors-validation-and-ownership)
- [Security and Transports](#security-and-transports)
- [Text Search Pagination](#text-search-pagination)
- [Place Response Accessors](#place-response-accessors)
- [Version 0.6 release notes](#version-06-release-notes)
- [Place Field Presets](#place-field-presets)

## Widget Defaults

`PlacesAutocompleteField` and `PlacesAutocompleteFormField` share the same
autocomplete options. The form field also adds the standard `FormField`
callbacks and validation options.

As of `0.7.0` the widget layer is built on
[`material_ui`](https://pub.dev/packages/material_ui), so the `InputDecoration` below — and the one
on `PlacesAutocompleteOverlay` and `PlacesAutocompleteOverlay.show()` — is
`material_ui`'s type, not `package:flutter/material.dart`'s. The name and every field on it are
unchanged; only the library it is imported from moved. See
[MIGRATION.md](../MIGRATION.md#070). Every other type in these tables comes from
`package:flutter/widgets.dart`, `painting`, `services`, or `foundation` and is unaffected.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `client` | `PlacesClient?` | `null` | Caller-owned client used for every request. Pass exactly one of `client` and `apiKey`. |
| `apiKey` | `String?` | `null` | The widget creates its own client from this key, closes it on dispose, and replaces it when the key changes. Sends no application identity — use `client` for an app-restricted mobile key. |
| `controller` | `PlacesAutocompleteController?` | `null` | When omitted, the widget owns an internal controller. |
| `decoration` | `InputDecoration?` | `null` | Falls back to `InputDecoration()` and preserves user styling. In the fullscreen search, where the field sits in the top bar, it has no border unless the decoration sets one. |
| `strings` | `PlacesStrings` | `const PlacesStrings()` | Localized widget labels and messages. |
| `languageCode` | `String?` | `null` | Preferred BCP-47 language code for autocomplete. |
| `regionCode` | `String?` | `null` | Preferred CLDR region code for autocomplete. |
| `origin` | `PlaceCoordinates?` | `null` | Makes Google return a straight-line distance for each suggestion, which the widget then renders. Does not bias or restrict results. For device location, see the [recipe](recipes.md#using-the-devices-location-as-the-origin) — the package never requests location permission. |
| `locationBias` | `LocationBias?` | `null` | Soft geographic preference. Cannot be combined with `locationRestriction`. |
| `locationRestriction` | `LocationRestriction?` | `null` | Hard geographic restriction. Cannot be combined with `locationBias`. |
| `includedPrimaryTypes` | `List<String>` | `const <String>[]` | Google primary type filters, such as `restaurant`, `cafe`, or `(cities)`. |
| `includedRegionCodes` | `List<String>` | `const <String>[]` | CLDR region-code filters. |
| `includePureServiceAreaBusinesses` | `bool` | `false` | Includes pure service-area businesses in autocomplete. |
| `fetchPlaceDetailsOnSelection` | `bool` | `true` | Resolves the selected place before `onSelection`, ending the autocomplete session with one Place Details request. `false` skips it. |
| `fetchTimeZoneOnSelection` | `bool` | `false` | Resolves details and then Google Time Zone data. |
| `selectionFields` | `Set<PlaceField>` | `PlaceFieldPresets.address` | Details fields used when selection details are fetched. The default is all Essentials. Because this request ends the autocomplete session, one Pro or Enterprise field bills it at Enterprise + Atmosphere. |
| `selectionLanguageCode` | `String?` | `null` | Overrides `languageCode` for follow-up details. |
| `selectionRegionCode` | `String?` | `null` | Overrides `regionCode` for follow-up details. |
| `selectionTimeZoneAt` | `DateTime?` | `null` | Time-zone timestamp; when omitted, the backend uses now. |
| `selectionTimeZoneLanguageCode` | `String?` | `null` | Time-zone language; falls back to selection language, then autocomplete language. |
| `fieldMode` | `PlacesAutocompleteFieldMode` | `PlacesAutocompleteFieldMode.inline` | `inline`, `dialog`, or `fullscreen`. |
| `onSelection` | `ValueChanged<PlaceSelection>?` | `null` | Called for selected place suggestions. |
| `onClearField` | `VoidCallback?` | `null` | Called after the clear action. |
| `onError` | `ValueChanged<Object>?` | `null` | Called for autocomplete/details/time-zone errors. |
| `maxSuggestions` | `int` | `5` | Clamped to Google Autocomplete's five-suggestion response limit. |
| `enabled` | `bool` | `true` | Enables text field interaction. |
| `autofocus` | `bool` | `false` | Requests focus when built. |
| `showPoweredByGoogle` | `bool` | `true` | Shows required Google attribution for suggestion UI. |
| `includeQueryPredictions` | `bool` | `false` | Adds query suggestions alongside place suggestions. |
| `onQuerySelection` | `ValueChanged<QuerySuggestion>?` | `null` | Called when a query suggestion is selected. |
| `suggestionBuilder` | `Widget Function(BuildContext, PlaceSuggestion)?` | `null` | Custom renderer for place suggestions. |

Additional `PlacesAutocompleteFormField` defaults:

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `validator` | `FormFieldValidator<PlaceSelection?>?` | `null` | Standard form validation callback. |
| `onSaved` | `FormFieldSetter<PlaceSelection?>?` | `null` | Standard form save callback. |
| `onReset` | `VoidCallback?` | `null` | Called after the initial selection is restored. |
| `forceErrorText` | `String?` | `null` | Forces the standard FormField error state. |
| `errorBuilder` | `FormFieldErrorBuilder?` | `null` | Builds custom error presentation. |
| `restorationId` | `String?` | `null` | Enables FormField state restoration. |
| `initialValue` | `PlaceSelection?` | `null` | Initial form value. |
| `autovalidateMode` | `AutovalidateMode` | `AutovalidateMode.disabled` | Standard form autovalidation mode. |

`PlacesAutocompleteOverlay.show()` accepts the same autocomplete options as the
field widgets, including `decoration`, `origin`, `enabled`,
`showPoweredByGoogle`, `suggestionBuilder`, and `onClearField`, plus these
overlay-specific fields:

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `context` | `BuildContext` | Required | Context used for dialog or route presentation. |
| `client` / `apiKey` | `PlacesClient?` / `String?` | `null` | Exactly one. Given a key, the overlay creates a client and closes it once the overlay has closed. |
| `controller` | `PlacesAutocompleteController?` | `null` | When omitted, the overlay creates and disposes one. |
| `initialText` | `String` | `''` | Initial text for an internally owned controller. |
| `mode` | `PlacesAutocompleteOverlayMode` | `PlacesAutocompleteOverlayMode.dialog` | `dialog` or `fullscreen`. |
| `useRootNavigator` | `bool` | `true` | Presents and dismisses with the root navigator. |
| `title` | `String?` | `null` | Falls back to `strings.overlayTitle`. Shown above the field in `dialog` mode; in `fullscreen` mode the field takes the top bar, so screen readers announce the title as the screen's name instead. |

When a `PlacesAutocompleteField` in `dialog` or `fullscreen` mode opens an
overlay, it forwards all of these automatically. Before `0.6.1` it dropped
`decoration`, `suggestionBuilder`, `showPoweredByGoogle`, `onClearField`, and
`enabled`.

## Client and Request Defaults

| API | Field | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `PlacesClient` | `apiKey` | `String` | Required | Google Maps Platform API key. |
| `PlacesClient` | `proxyConfiguration` | `PlacesProxyConfiguration?` | `null` | Typed keyless proxy endpoint and authentication configuration. |
| `PlacesClient` | `proxyBaseUrl` | `String?` | `null` | Deprecated in `0.6.0`; use `proxyConfiguration` or `PlacesClient.proxy()`. Removed in `1.0.0`. |
| `PlacesClient` | `timeZoneBaseUrl` | `String?` | `null` | Optional Time Zone API base URL. |
| `PlacesClient` | `httpClient` | `http.Client?` | `null` | IO backend override; unsupported on web. |
| `PlacesClient.proxy()` | `placesEndpoint` | `Uri` | Required | Keyless Places proxy base endpoint. |
| `PlacesClient.proxy()` | `timeZoneEndpoint` | `Uri?` | `null` | Exact keyless Time Zone proxy endpoint. |
| `PlacesClient.proxy()` | `authentication` | `PlacesProxyAuthenticationProvider?` | `null` | Fresh client-to-proxy headers for each request. |
| `PlacesClient` | `options` | `PlacesClientOptions` | `const PlacesClientOptions()` | Request deadline, ownership, application identity, and web behavior. |
| `PlacesClientOptions` | `requestTimeout` | `Duration` | 15 seconds | Positive per-operation HTTP or JavaScript deadline. |
| `PlacesClientOptions` | `httpClientOwnership` | `PlacesHttpClientOwnership` | `caller` | Whether the caller or `PlacesClient` closes an injected client. |
| `PlacesClientOptions` | `applicationIdentity` | `PlacesApplicationIdentity?` | `null` | Direct Android/iOS REST application-restriction headers; unsupported on web and omitted from proxy traffic. |
| `PlacesClientOptions` | `web` | `PlacesWebOptions` | `const PlacesWebOptions()` | Browser script loading and HTTP fallback policy. |
| `PlacesWebOptions` | `versionChannel` | `PlacesWebVersionChannel` | `weekly` | Injected Maps JavaScript weekly or quarterly channel. |
| `PlacesWebOptions` | `cspNonce` | `String?` | `null` | Nonce copied to the injected Maps JavaScript element and redacted from diagnostics. |
| `PlacesWebOptions` | `initializationTimeout` | `Duration` | 10 seconds | Positive script loading/initialization deadline. |
| `PlacesWebOptions` | `fallbackPolicy` | `PlacesWebFallbackPolicy` | `direct` | `direct` is deprecated in `0.6.0`; prefer `proxyOnly`. `disabled` rejects all HTTP operations. |
| `PlacesClient.endAutocompleteSession` | `token` | `AutocompleteSessionToken` | Required | Releases transport state for an abandoned or otherwise concluded headless session. |
| `AutocompleteRequest` | `input` | `String` | Required | User-entered query text. |
| `AutocompleteRequest` | `sessionToken` | `AutocompleteSessionToken?` | `null` | Groups autocomplete and details billing sessions. |
| `AutocompleteRequest` | `languageCode` | `String?` | `null` | Preferred result language. |
| `AutocompleteRequest` | `regionCode` | `String?` | `null` | Preferred result region. |
| `AutocompleteRequest` | `inputOffset` | `int?` | `null` | Cursor offset inside `input`. |
| `AutocompleteRequest` | `origin` | `PlaceCoordinates?` | `null` | Origin used for distance calculations. |
| `AutocompleteRequest` | `locationBias` | `LocationBias?` | `null` | Soft geographic preference. |
| `AutocompleteRequest` | `locationRestriction` | `LocationRestriction?` | `null` | Hard geographic restriction. |
| `AutocompleteRequest` | `includedPrimaryTypes` | `List<String>` | `const <String>[]` | Primary type filters. |
| `AutocompleteRequest` | `includedRegionCodes` | `List<String>` | `const <String>[]` | Region-code filters. |
| `AutocompleteRequest` | `includePureServiceAreaBusinesses` | `bool` | `false` | Includes service-area businesses. |
| `AutocompleteRequest` | `includeFutureOpeningBusinesses` | `bool` | `false` | Includes businesses expected to open in the future. |
| `AutocompleteRequest` | `includeQueryPredictions` | `bool` | `false` | Enables `QuerySuggestion` results in `autocompleteSuggestions()`. |
| `PlacesClient.fetchPlaceById` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.address` | Same default as `PlaceDetailsRequest`. |
| `PlaceDetailsRequest` | `placeId` | `String` | Required | Place id or `places/{id}` resource name. |
| `PlaceDetailsRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.address` | Place Details field mask. The default bills as Essentials. |
| `PlaceDetailsRequest` | `languageCode` | `String?` | `null` | Preferred details language. |
| `PlaceDetailsRequest` | `regionCode` | `String?` | `null` | Preferred details region. |
| `PlaceDetailsRequest` | `sessionToken` | `AutocompleteSessionToken?` | `null` | Autocomplete session token for selected place. |
| `PlaceSelection` | `sessionToken` | `AutocompleteSessionToken?` | `null` | Session active when the suggestion was selected. |
| `PhotoMediaRequest` | `name` | `String` | Required | Photo resource name from `PlacePhoto.name`. |
| `PhotoMediaRequest` | `maxWidthPx` | `int?` | `null` | At least one of width or height is required. |
| `PhotoMediaRequest` | `maxHeightPx` | `int?` | `null` | At least one of width or height is required. |
| `TimeZoneRequest` | `location` | `PlaceCoordinates` | Required | Coordinates to resolve. |
| `TimeZoneRequest` | `timestamp` | `DateTime?` | `null` | When omitted, the backend uses the current time. |
| `TimeZoneRequest` | `languageCode` | `String?` | `null` | Localized time-zone names. |
| `TextSearchRequest` | `textQuery` | `String` | Required | Free-text search query. |
| `TextSearchRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.minimal` | Search result field mask. The default bills as Text Search Pro. |
| `TextSearchRequest` | `languageCode` | `String?` | `null` | Preferred result language. |
| `TextSearchRequest` | `regionCode` | `String?` | `null` | Preferred result region. |
| `TextSearchRequest` | `includedType` | `String?` | `null` | Optional type filter. |
| `TextSearchRequest` | `strictTypeFiltering` | `bool` | `false` | Applies `includedType` strictly. |
| `TextSearchRequest` | `locationBias` | `LocationBias?` | `null` | Soft geographic preference. |
| `TextSearchRequest` | `locationRestriction` | `LocationRestriction?` | `null` | Hard geographic restriction. |
| `TextSearchRequest` | `pageSize` | `int?` | `null` | Requested results per page; Google defaults and caps this at 20. |
| `TextSearchRequest` | `pageToken` | `String?` | `null` | Token from the preceding `TextSearchPage`. |
| `TextSearchRequest` | `priceLevels` | `List<PlacePriceLevel>` | `const <PlacePriceLevel>[]` | Price-level filters; `free` and `unspecified` are response-only. |
| `TextSearchRequest` | `includePureServiceAreaBusinesses` | `bool` | `false` | Includes businesses without a customer-facing physical location. |
| `TextSearchRequest` | `includeFutureOpeningBusinesses` | `bool` | `false` | Includes businesses expected to open in the future. |
| `TextSearchRequest` | `maxResultCount` | `int?` | `null` | Deprecated in `0.6.0`; use `pageSize`. Removed in `1.0.0`. |
| `TextSearchRequest` | `minRating` | `double?` | `null` | Minimum rating filter. |
| `TextSearchRequest` | `openNow` | `bool?` | `null` | Restricts results to currently open places. |
| `TextSearchRequest` | `rankPreference` | `SearchByTextRankPreference` | `SearchByTextRankPreference.relevance` | Text-search ranking behavior. |
| `NearbySearchRequest` | `locationRestriction` | `LocationRestriction` | Required | Required nearby search area. |
| `NearbySearchRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.minimal` | Search result field mask. The default bills as Nearby Search Pro. |
| `NearbySearchRequest` | `languageCode` | `String?` | `null` | Preferred result language. |
| `NearbySearchRequest` | `regionCode` | `String?` | `null` | Preferred result region. |
| `NearbySearchRequest` | `includedTypes` | `List<String>` | `const <String>[]` | Included place types. |
| `NearbySearchRequest` | `excludedTypes` | `List<String>` | `const <String>[]` | Excluded place types. |
| `NearbySearchRequest` | `includedPrimaryTypes` | `List<String>` | `const <String>[]` | Included primary place types. |
| `NearbySearchRequest` | `excludedPrimaryTypes` | `List<String>` | `const <String>[]` | Excluded primary place types. |
| `NearbySearchRequest` | `maxResultCount` | `int?` | `null` | Requested result cap. |
| `NearbySearchRequest` | `includeFutureOpeningBusinesses` | `bool` | `false` | Includes businesses expected to open in the future. |
| `NearbySearchRequest` | `rankPreference` | `SearchNearbyRankPreference` | `SearchNearbyRankPreference.popularity` | Nearby-search ranking behavior. |

Every asynchronous `PlacesClient` operation accepts an optional
`PlacesCancellationToken`. Cancellation is reported as
`PlacesErrorKind.cancellation`; HTTP transports also abort the underlying
request. `PlacePhoto.authors` provides typed required author attribution, and
`PlacesPhotoAttribution` renders it next to a displayed image.

## Autocomplete Sessions

Use one `AutocompleteSessionToken` for all requests in a headless autocomplete
flow and pass that same token to Place Details for the selected suggestion.
Call `PlacesClient.endAutocompleteSession(token)` when the flow is abandoned
without details. The field, form field, and overlay widgets perform session
cleanup automatically.

`PlaceSelection.sessionToken` records the token active at selection time. On
web, the backend retains the matching JavaScript prediction and resolves it
with `toPlace().fetchFields()` so the session association is preserved. Cached
transport state is bounded and expires after inactivity.

## Errors, Validation, and Ownership

Every package-generated failure is a `PlacesException`. Its public diagnostic
contract includes:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `PlacesErrorKind` | Validation, configuration, network, timeout, cancellation, HTTP, Google API, proxy, JavaScript, or unknown. |
| `operation` | `PlacesOperation?` | Autocomplete, details, photo, Time Zone, text search, nearby search, or client initialization. |
| `code` | `String?` | Stable package code or Google status/code when available. |
| `statusCode` | `int?` | HTTP response status when applicable. |
| `retryable` | `bool` | Whether retrying later may reasonably succeed. |
| `message` | `String` | Safe human-readable description. |
| `metadata` | `Map<String, Object?>` | Redacted context without request credentials or session values. |

Validation runs before transport work. It covers coordinate and area bounds,
endpoint-specific area shapes, non-empty IDs and masks, URL-safe session
tokens, Unicode cursor offsets, type/region limits and conflicts, pagination,
ratings, result counts, and Place Photo dimensions in `1...4800`.

Injected HTTP clients are caller-owned unless
`PlacesHttpClientOwnership.placesClient` is selected. Internally created clients
are always package-owned. Injection is unsupported on web and produces a typed
configuration error rather than being ignored.

## Security and Transports

`PlacesClient.proxy()` never accepts or forwards a Google API key.
`PlacesProxyConfiguration` can also be attached to a standard client when Maps
JavaScript should remain primary and REST-only operations should use an
authenticated proxy. Endpoint URIs are validated and authentication providers
cannot override `key`, `X-Goog-Api-Key`, field masks, content headers, or host
headers.

Direct mobile clients can set `PlacesApplicationIdentity.android(packageName,
sha1CertificateFingerprint)` or `.ios(bundleIdentifier)`. These values become
Google's documented application-restriction headers only on direct HTTP
traffic; they are rejected on web and omitted from proxy traffic.

On web, `PlacesWebFallbackPolicy.proxyOnly` requires a proxy for HTTP work and
`disabled` rejects HTTP work. Deprecated `direct` remains the `0.x`
compatibility default and is scheduled to stop being the default in `1.0.0`.
See [Security and transport configuration](security_and_transports.md) for the
deployment matrix and server responsibilities.

## Text Search Pagination

`PlacesClient.searchTextPage()` returns an immutable `TextSearchPage` with
`results`, `nextPageToken`, `searchUri`, and `hasNextPage`. When requesting a
later page, keep every filter from the initial request unchanged and only set
the returned `pageToken` (and, if needed, `pageSize`).

`PlacesClient.searchText()` remains available for callers that only need a
`List<PlaceData>` and intentionally discards the pagination metadata. On web,
`searchTextPage()` uses the configured HTTP or proxy path because Maps
JavaScript does not expose REST `nextPageToken` and `searchUri` metadata.

## Place Response Accessors

Every `PlaceField` has a matching `PlaceData` property. Stable, bounded
structures use typed models: `PlaceDate`, `PlacePlusCode`, `PlaceTimeZone`,
`PlaceGoogleMapsLinks`, `PlacePriceRange`/`PlaceMoney`, `PlaceAttribution`,
`PlaceResourceReference`, `PlacePaymentOptions`, `PlaceParkingOptions`,
`PlaceAccessibilityOptions`, and the `PlaceTransit*` models.

The REST resource's `name` field is exposed as `PlaceData.resourceName` to
distinguish it from the human-readable `displayName`.

Large or evolving payloads—including opening hours, address descriptors, EV
and fuel options, generative/review/area summaries, and consumer alerts—are
exposed as deeply immutable JSON maps or lists. `PlaceData.rawData` is also a
deeply immutable view of the full response.

`PlaceData.priceLevel` retains Google's raw string. Use
`PlaceData.priceLevelValue` for a typed `PlacePriceLevel`; it returns `null`
when Google introduces a value the installed package does not yet know.

## Version 0.6 release notes

For the `0.5.x` to `0.6.0` Text Search deprecation and replacement examples,
see [What's new in 0.6.0](whats_new_0_6_0.md). `maxResultCount` remains a
compatibility API until its planned removal in `1.0.0`. As of `0.6.1` it is
omitted from the request whenever `pageSize` is set, matching what Google does
and what the Maps JavaScript path already did.

For the `0.6.1` security fix, the launcher-mode customization fixes, and
`origin`, see [What's new in 0.6.1](whats_new_0_6_1.md).

## Place Field Presets

`PlaceField` values are used by Place Details, Text Search, and Nearby Search
field masks. The table shows each field's Place Details billing tier, as
published in Google's
[data fields](https://developers.google.com/maps/documentation/places/web-service/data-fields)
table (checked 2026-10-20), and which of the package's presets include it.

Google bills a request at the tier of its most expensive field, so the presets
bill as:

| Preset | Place Details | Text Search | Nearby Search | Default for |
| --- | --- | --- | --- | --- |
| `address` | Essentials | Pro | Pro | widget `selectionFields`, `PlaceDetailsRequest`, `fetchPlaceById` |
| `minimal` | Pro | Pro | Pro | `TextSearchRequest`, `NearbySearchRequest` |
| `recommended` | Enterprise | Enterprise | Enterprise | — |
| `rich` | Enterprise + Atmosphere | Enterprise + Atmosphere | Enterprise + Atmosphere | — |

Text Search and Nearby Search bill address and location fields as Pro, and
Nearby Search has no tier below Pro. When a Place Details request above
Essentials ends an autocomplete session, Google bills it at Enterprise +
Atmosphere regardless of its fields; see
[session pricing](https://developers.google.com/maps/documentation/places/web-service/session-pricing).

| Field | API field name | Place Details tier | Address | Minimal | Recommended | Rich |
| --- | --- | --- | --- | --- | --- | --- |
| `PlaceField.id` | `id` | Essentials (IDs Only) | Yes | Yes | Yes | Yes |
| `PlaceField.name` | `name` | Essentials (IDs Only) | No | No | No | No |
| `PlaceField.displayName` | `displayName` | Pro | No | Yes | Yes | Yes |
| `PlaceField.formattedAddress` | `formattedAddress` | Essentials | Yes | Yes | Yes | Yes |
| `PlaceField.shortFormattedAddress` | `shortFormattedAddress` | Essentials | Yes | No | No | No |
| `PlaceField.adrFormatAddress` | `adrFormatAddress` | Essentials | No | No | No | No |
| `PlaceField.postalAddress` | `postalAddress` | Essentials | No | No | No | Yes |
| `PlaceField.location` | `location` | Essentials | Yes | Yes | Yes | Yes |
| `PlaceField.viewport` | `viewport` | Essentials | No | No | No | Yes |
| `PlaceField.types` | `types` | Essentials | No | No | No | No |
| `PlaceField.primaryType` | `primaryType` | Pro | No | No | Yes | Yes |
| `PlaceField.primaryTypeDisplayName` | `primaryTypeDisplayName` | Pro | No | No | Yes | Yes |
| `PlaceField.googleMapsTypeLabel` | `googleMapsTypeLabel` | Pro | No | No | No | No |
| `PlaceField.businessStatus` | `businessStatus` | Pro | No | No | No | Yes |
| `PlaceField.openingDate` | `openingDate` | Pro | No | No | No | No |
| `PlaceField.googleMapsUri` | `googleMapsUri` | Pro | No | No | Yes | Yes |
| `PlaceField.googleMapsLinks` | `googleMapsLinks` | Pro | No | No | No | No |
| `PlaceField.websiteUri` | `websiteUri` | Enterprise | No | No | No | Yes |
| `PlaceField.nationalPhoneNumber` | `nationalPhoneNumber` | Enterprise | No | No | No | Yes |
| `PlaceField.internationalPhoneNumber` | `internationalPhoneNumber` | Enterprise | No | No | No | Yes |
| `PlaceField.rating` | `rating` | Enterprise | No | No | Yes | Yes |
| `PlaceField.userRatingCount` | `userRatingCount` | Enterprise | No | No | Yes | Yes |
| `PlaceField.priceLevel` | `priceLevel` | Enterprise | No | No | No | Yes |
| `PlaceField.priceRange` | `priceRange` | Enterprise | No | No | No | No |
| `PlaceField.plusCode` | `plusCode` | Essentials | No | No | No | No |
| `PlaceField.attributions` | `attributions` | Essentials (IDs Only) | No | No | No | No |
| `PlaceField.iconMaskBaseUri` | `iconMaskBaseUri` | Pro | No | No | Yes | Yes |
| `PlaceField.iconBackgroundColor` | `iconBackgroundColor` | Pro | No | No | Yes | Yes |
| `PlaceField.utcOffsetMinutes` | `utcOffsetMinutes` | Pro | No | No | No | No |
| `PlaceField.timeZone` | `timeZone` | Pro | No | No | No | No |
| `PlaceField.editorialSummary` | `editorialSummary` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.currentOpeningHours` | `currentOpeningHours` | Enterprise | No | No | No | Yes |
| `PlaceField.regularOpeningHours` | `regularOpeningHours` | Enterprise | No | No | No | Yes |
| `PlaceField.currentSecondaryOpeningHours` | `currentSecondaryOpeningHours` | Enterprise | No | No | No | No |
| `PlaceField.regularSecondaryOpeningHours` | `regularSecondaryOpeningHours` | Enterprise | No | No | No | No |
| `PlaceField.photos` | `photos` | Essentials (IDs Only) | No | No | No | Yes |
| `PlaceField.reviews` | `reviews` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.addressComponents` | `addressComponents` | Essentials | Yes | No | No | Yes |
| `PlaceField.containingPlaces` | `containingPlaces` | Pro | No | No | No | No |
| `PlaceField.subDestinations` | `subDestinations` | Pro | No | No | No | No |
| `PlaceField.delivery` | `delivery` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.dineIn` | `dineIn` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.takeout` | `takeout` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.curbsidePickup` | `curbsidePickup` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.reservable` | `reservable` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesBreakfast` | `servesBreakfast` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesLunch` | `servesLunch` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesDinner` | `servesDinner` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesBeer` | `servesBeer` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesWine` | `servesWine` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesBrunch` | `servesBrunch` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.servesVegetarianFood` | `servesVegetarianFood` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.servesCocktails` | `servesCocktails` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.servesDessert` | `servesDessert` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.servesCoffee` | `servesCoffee` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.outdoorSeating` | `outdoorSeating` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.liveMusic` | `liveMusic` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.menuForChildren` | `menuForChildren` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.allowsDogs` | `allowsDogs` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.restroom` | `restroom` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.goodForChildren` | `goodForChildren` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.goodForGroups` | `goodForGroups` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.goodForWatchingSports` | `goodForWatchingSports` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.paymentOptions` | `paymentOptions` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.parkingOptions` | `parkingOptions` | Enterprise + Atmosphere | No | No | No | Yes |
| `PlaceField.accessibilityOptions` | `accessibilityOptions` | Pro | No | No | No | Yes |
| `PlaceField.addressDescriptor` | `addressDescriptor` | Essentials | No | No | No | No |
| `PlaceField.evChargeOptions` | `evChargeOptions` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.fuelOptions` | `fuelOptions` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.generativeSummary` | `generativeSummary` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.reviewSummary` | `reviewSummary` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.evChargeAmenitySummary` | `evChargeAmenitySummary` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.neighborhoodSummary` | `neighborhoodSummary` | Enterprise + Atmosphere | No | No | No | No |
| `PlaceField.consumerAlert` | `consumerAlert` | Essentials (IDs Only) | No | No | No | No |
| `PlaceField.transitStation` | `transitStation` | Enterprise | No | No | No | No |
| `PlaceField.pureServiceAreaBusiness` | `pureServiceAreaBusiness` | Pro | No | No | No | No |
| `PlaceField.movedPlace` | `movedPlace` | Essentials (IDs Only) | No | No | No | No |
| `PlaceField.movedPlaceId` | `movedPlaceId` | Essentials (IDs Only) | No | No | No | No |
