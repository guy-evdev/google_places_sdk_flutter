# API Reference

Detailed defaults and field-mask preset reference for
`google_places_sdk_flutter`.

## Contents

- [Widget Defaults](#widget-defaults)
- [Client and Request Defaults](#client-and-request-defaults)
- [Place Field Presets](#place-field-presets)

## Widget Defaults

`PlacesAutocompleteField` and `PlacesAutocompleteFormField` share the same
autocomplete options. The form field also adds the standard `FormField`
callbacks and validation options.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `client` | `PlacesClient` | Required | Used for autocomplete, details, time-zone, search, and photo calls. |
| `controller` | `PlacesAutocompleteController?` | `null` | When omitted, the widget owns an internal controller. |
| `decoration` | `InputDecoration?` | `null` | Falls back to `InputDecoration()` and preserves user styling. |
| `strings` | `PlacesStrings` | `const PlacesStrings()` | Localized widget labels and messages. |
| `languageCode` | `String?` | `null` | Preferred BCP-47 language code for autocomplete. |
| `regionCode` | `String?` | `null` | Preferred CLDR region code for autocomplete. |
| `locationBias` | `LocationBias?` | `null` | Soft geographic preference. Cannot be combined with `locationRestriction`. |
| `locationRestriction` | `LocationRestriction?` | `null` | Hard geographic restriction. Cannot be combined with `locationBias`. |
| `includedPrimaryTypes` | `List<String>` | `const <String>[]` | Google primary type filters, such as `restaurant`, `cafe`, or `(cities)`. |
| `includedRegionCodes` | `List<String>` | `const <String>[]` | CLDR region-code filters. |
| `includePureServiceAreaBusinesses` | `bool` | `false` | Includes pure service-area businesses in autocomplete. |
| `fetchPlaceDetailsOnSelection` | `bool` | `false` | Resolves the selected place before `onSelection`. |
| `fetchTimeZoneOnSelection` | `bool` | `false` | Resolves details and then Google Time Zone data. |
| `selectionFields` | `Set<PlaceField>` | `PlaceFieldPresets.recommended` | Details fields used when selection details are fetched. |
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
| `initialValue` | `PlaceSelection?` | `null` | Initial form value. |
| `autovalidateMode` | `AutovalidateMode` | `AutovalidateMode.disabled` | Standard form autovalidation mode. |

`PlacesAutocompleteOverlay.show()` uses the same autocomplete defaults, with
these overlay-specific fields:

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `context` | `BuildContext` | Required | Context used for dialog or route presentation. |
| `client` | `PlacesClient` | Required | Same client used by field widgets. |
| `controller` | `PlacesAutocompleteController?` | `null` | When omitted, the overlay creates and disposes one. |
| `initialText` | `String` | `''` | Initial text for an internally owned controller. |
| `mode` | `PlacesAutocompleteOverlayMode` | `PlacesAutocompleteOverlayMode.dialog` | `dialog` or `fullscreen`. |
| `useRootNavigator` | `bool` | `true` | Presents and dismisses with the root navigator. |
| `title` | `String?` | `null` | Falls back to `strings.overlayTitle`. |

## Client and Request Defaults

| API | Field | Type | Default | Notes |
| --- | --- | --- | --- | --- |
| `PlacesClient` | `apiKey` | `String` | Required | Google Maps Platform API key. |
| `PlacesClient` | `proxyBaseUrl` | `String?` | `null` | Optional Places proxy base URL. |
| `PlacesClient` | `timeZoneBaseUrl` | `String?` | `null` | Optional Time Zone API base URL. |
| `PlacesClient` | `httpClient` | `http.Client?` | `null` | IO backend override; ignored by web backend. |
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
| `AutocompleteRequest` | `includeQueryPredictions` | `bool` | `false` | Enables `QuerySuggestion` results in `autocompleteSuggestions()`. |
| `PlaceDetailsRequest` | `placeId` | `String` | Required | Place id or `places/{id}` resource name. |
| `PlaceDetailsRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.recommended` | Place Details field mask. |
| `PlaceDetailsRequest` | `languageCode` | `String?` | `null` | Preferred details language. |
| `PlaceDetailsRequest` | `regionCode` | `String?` | `null` | Preferred details region. |
| `PlaceDetailsRequest` | `sessionToken` | `AutocompleteSessionToken?` | `null` | Autocomplete session token for selected place. |
| `PhotoMediaRequest` | `name` | `String` | Required | Photo resource name from `PlacePhoto.name`. |
| `PhotoMediaRequest` | `maxWidthPx` | `int?` | `null` | At least one of width or height is required. |
| `PhotoMediaRequest` | `maxHeightPx` | `int?` | `null` | At least one of width or height is required. |
| `TimeZoneRequest` | `location` | `PlaceCoordinates` | Required | Coordinates to resolve. |
| `TimeZoneRequest` | `timestamp` | `DateTime?` | `null` | When omitted, the backend uses the current time. |
| `TimeZoneRequest` | `languageCode` | `String?` | `null` | Localized time-zone names. |
| `TextSearchRequest` | `textQuery` | `String` | Required | Free-text search query. |
| `TextSearchRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.recommended` | Search result field mask. |
| `TextSearchRequest` | `languageCode` | `String?` | `null` | Preferred result language. |
| `TextSearchRequest` | `regionCode` | `String?` | `null` | Preferred result region. |
| `TextSearchRequest` | `includedType` | `String?` | `null` | Optional type filter. |
| `TextSearchRequest` | `strictTypeFiltering` | `bool` | `false` | Applies `includedType` strictly. |
| `TextSearchRequest` | `locationBias` | `LocationBias?` | `null` | Soft geographic preference. |
| `TextSearchRequest` | `locationRestriction` | `LocationRestriction?` | `null` | Hard geographic restriction. |
| `TextSearchRequest` | `maxResultCount` | `int?` | `null` | Requested result cap. |
| `TextSearchRequest` | `minRating` | `double?` | `null` | Minimum rating filter. |
| `TextSearchRequest` | `openNow` | `bool?` | `null` | Restricts results to currently open places. |
| `TextSearchRequest` | `rankPreference` | `SearchByTextRankPreference` | `SearchByTextRankPreference.relevance` | Text-search ranking behavior. |
| `NearbySearchRequest` | `locationRestriction` | `LocationRestriction` | Required | Required nearby search area. |
| `NearbySearchRequest` | `fields` | `Set<PlaceField>` | `PlaceFieldPresets.recommended` | Search result field mask. |
| `NearbySearchRequest` | `languageCode` | `String?` | `null` | Preferred result language. |
| `NearbySearchRequest` | `regionCode` | `String?` | `null` | Preferred result region. |
| `NearbySearchRequest` | `includedTypes` | `List<String>` | `const <String>[]` | Included place types. |
| `NearbySearchRequest` | `excludedTypes` | `List<String>` | `const <String>[]` | Excluded place types. |
| `NearbySearchRequest` | `includedPrimaryTypes` | `List<String>` | `const <String>[]` | Included primary place types. |
| `NearbySearchRequest` | `excludedPrimaryTypes` | `List<String>` | `const <String>[]` | Excluded primary place types. |
| `NearbySearchRequest` | `maxResultCount` | `int?` | `null` | Requested result cap. |
| `NearbySearchRequest` | `rankPreference` | `SearchNearbyRankPreference` | `SearchNearbyRankPreference.popularity` | Nearby-search ranking behavior. |

## Place Field Presets

`PlaceField` values are used by Place Details, Text Search, and Nearby Search
field masks. The table shows whether each field is included by the package's
default presets.

| Field | API field name | Minimal | Recommended | Rich |
| --- | --- | --- | --- | --- |
| `PlaceField.id` | `id` | Yes | Yes | Yes |
| `PlaceField.name` | `name` | No | No | No |
| `PlaceField.displayName` | `displayName` | Yes | Yes | Yes |
| `PlaceField.formattedAddress` | `formattedAddress` | Yes | Yes | Yes |
| `PlaceField.shortFormattedAddress` | `shortFormattedAddress` | No | No | No |
| `PlaceField.adrFormatAddress` | `adrFormatAddress` | No | No | No |
| `PlaceField.postalAddress` | `postalAddress` | No | No | Yes |
| `PlaceField.location` | `location` | Yes | Yes | Yes |
| `PlaceField.viewport` | `viewport` | No | No | Yes |
| `PlaceField.types` | `types` | No | No | No |
| `PlaceField.primaryType` | `primaryType` | No | Yes | Yes |
| `PlaceField.primaryTypeDisplayName` | `primaryTypeDisplayName` | No | Yes | Yes |
| `PlaceField.businessStatus` | `businessStatus` | No | No | Yes |
| `PlaceField.googleMapsUri` | `googleMapsUri` | No | Yes | Yes |
| `PlaceField.websiteUri` | `websiteUri` | No | No | Yes |
| `PlaceField.nationalPhoneNumber` | `nationalPhoneNumber` | No | No | Yes |
| `PlaceField.internationalPhoneNumber` | `internationalPhoneNumber` | No | No | Yes |
| `PlaceField.rating` | `rating` | No | Yes | Yes |
| `PlaceField.userRatingCount` | `userRatingCount` | No | Yes | Yes |
| `PlaceField.priceLevel` | `priceLevel` | No | No | Yes |
| `PlaceField.plusCode` | `plusCode` | No | No | No |
| `PlaceField.iconMaskBaseUri` | `iconMaskBaseUri` | No | Yes | Yes |
| `PlaceField.iconBackgroundColor` | `iconBackgroundColor` | No | Yes | Yes |
| `PlaceField.utcOffsetMinutes` | `utcOffsetMinutes` | No | No | No |
| `PlaceField.currentOpeningHours` | `currentOpeningHours` | No | No | Yes |
| `PlaceField.regularOpeningHours` | `regularOpeningHours` | No | No | Yes |
| `PlaceField.currentSecondaryOpeningHours` | `currentSecondaryOpeningHours` | No | No | No |
| `PlaceField.regularSecondaryOpeningHours` | `regularSecondaryOpeningHours` | No | No | No |
| `PlaceField.photos` | `photos` | No | No | Yes |
| `PlaceField.reviews` | `reviews` | No | No | Yes |
| `PlaceField.addressComponents` | `addressComponents` | No | No | Yes |
| `PlaceField.delivery` | `delivery` | No | No | Yes |
| `PlaceField.dineIn` | `dineIn` | No | No | Yes |
| `PlaceField.takeout` | `takeout` | No | No | Yes |
| `PlaceField.reservable` | `reservable` | No | No | Yes |
| `PlaceField.servesBreakfast` | `servesBreakfast` | No | No | Yes |
| `PlaceField.servesLunch` | `servesLunch` | No | No | Yes |
| `PlaceField.servesDinner` | `servesDinner` | No | No | Yes |
| `PlaceField.servesBeer` | `servesBeer` | No | No | Yes |
| `PlaceField.servesWine` | `servesWine` | No | No | Yes |
| `PlaceField.servesDessert` | `servesDessert` | No | No | Yes |
| `PlaceField.servesCoffee` | `servesCoffee` | No | No | Yes |
| `PlaceField.outdoorSeating` | `outdoorSeating` | No | No | Yes |
| `PlaceField.restroom` | `restroom` | No | No | Yes |
| `PlaceField.goodForChildren` | `goodForChildren` | No | No | Yes |
| `PlaceField.goodForGroups` | `goodForGroups` | No | No | Yes |
| `PlaceField.paymentOptions` | `paymentOptions` | No | No | Yes |
| `PlaceField.parkingOptions` | `parkingOptions` | No | No | Yes |
| `PlaceField.accessibilityOptions` | `accessibilityOptions` | No | No | Yes |
| `PlaceField.addressDescriptor` | `addressDescriptor` | No | No | No |
| `PlaceField.evChargeOptions` | `evChargeOptions` | No | No | No |
| `PlaceField.fuelOptions` | `fuelOptions` | No | No | No |
| `PlaceField.generativeSummary` | `generativeSummary` | No | No | No |
| `PlaceField.pureServiceAreaBusiness` | `pureServiceAreaBusiness` | No | No | No |
| `PlaceField.movedPlace` | `movedPlace` | No | No | No |
| `PlaceField.movedPlaceId` | `movedPlaceId` | No | No | No |
