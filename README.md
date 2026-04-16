# Google Places SDK Flutter

[![pub package](https://img.shields.io/pub/v/google_places_sdk_flutter.svg)](https://pub.dev/packages/google_places_sdk_flutter)
[![CI](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml)


Cross-platform Google Places client and widget toolkit for Flutter, built on Places API (New).

The package includes package-owned request and response models, a
cross-platform `PlacesClient`, and autocomplete widgets for inline, form,
dialog, and fullscreen flows. The widget layer is locale-aware, RTL-friendly,
and designed to work consistently across Android, iOS, web, macOS, Windows,
and Linux.

## Preview

Overview:

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/example.gif" alt="Package example" width="320" />
</p>

Sample flows (Inline field, dialog launcher, fullscreen launcher, and rich result payload):

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/text_field_mode.png" alt="Inline field mode" width="200" />
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/dialog_mode.png" alt="Dialog mode" width="200" />
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/fullscreen_mode.png" alt="Fullscreen mode" width="200" />
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/rich_result.png" alt="Rich result payload" width="200" />
</p>

## Features

- Places API (New) autocomplete
- Optional place-details fetch on selection
- Optional Google Time Zone API fetch on selection
- Text search and nearby search client APIs
- Inline field, dialog launcher, and fullscreen launcher modes
- Customizable strings and `InputDecoration`
- Locale support with `languageCode` and `regionCode`
- Rich field-mask control with `PlaceField` and `PlaceFieldPresets`
- Typed address support through `postalAddress`, `addressComponents`, and convenience getters

## Installation

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  google_places_sdk_flutter: latest_version
```

Then create a client with your Google Maps Platform API key:

```dart
final client = PlacesClient(
  apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
);
```

Official Google docs:
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service)
- [Place Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- [Place Details (New)](https://developers.google.com/maps/documentation/places/web-service/place-details)
- [Time Zone API](https://developers.google.com/maps/documentation/timezone/requests-timezone)

On web, the package uses the Google Maps JavaScript Places library behind the
same `PlacesClient` API.

## Minimal Example

```dart
import 'package:flutter/material.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

class MinimalPlacesField extends StatefulWidget {
  const MinimalPlacesField({super.key});

  @override
  State<MinimalPlacesField> createState() => _MinimalPlacesFieldState();
}

class _MinimalPlacesFieldState extends State<MinimalPlacesField> {
  final _client = PlacesClient(
    apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
  );

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PlacesAutocompleteField(
      client: _client,
      onSelection: (selection) {
        debugPrint(selection.displayText);
      },
    );
  }
}
```

## Common Widget Example

```dart
final controller = PlacesAutocompleteController();

PlacesAutocompleteField(
  client: client,
  controller: controller,
  fieldMode: PlacesAutocompleteFieldMode.inline,
  strings: const PlacesStrings(
    searchHint: 'Search for a place',
  ),
  decoration: const InputDecoration(
    labelText: 'Place',
    border: OutlineInputBorder(),
  ),
  languageCode: 'en',
  regionCode: 'us',
  includedPrimaryTypes: const <String>['restaurant', 'cafe'],
  includedRegionCodes: const <String>['us'],
  fetchPlaceDetailsOnSelection: true,
  fetchTimeZoneOnSelection: true,
  selectionFields: PlaceFieldPresets.rich,
  onSelection: (selection) {
    debugPrint(selection.displayText);
    debugPrint(selection.place?.formattedAddress);
    debugPrint(selection.timeZone?.timeZoneId);
  },
  onClearField: () {
    debugPrint('Cleared');
  },
  onError: (error) {
    debugPrint(error.toString());
  },
)
```

## Form Example

Use `PlacesAutocompleteFormField` when autocomplete selection should
participate in form validation and saving.

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: PlacesAutocompleteFormField(
    client: client,
    decoration: const InputDecoration(
      labelText: 'Place',
      border: OutlineInputBorder(),
    ),
    fetchPlaceDetailsOnSelection: true,
    selectionFields: PlaceFieldPresets.recommended,
    validator: (selection) {
      if (selection == null) {
        return 'Please choose a place';
      }
      return null;
    },
    onSaved: (selection) {
      debugPrint(selection?.placeId);
    },
  ),
)
```

## Field Options

`PlacesAutocompleteField` supports the following public options:

```dart
PlacesAutocompleteField(
  key: key,
  client: client,
  controller: controller,
  decoration: decoration,
  strings: strings,
  languageCode: languageCode,
  regionCode: regionCode,
  locationBias: locationBias,
  locationRestriction: locationRestriction,
  includedPrimaryTypes: includedPrimaryTypes,
  includedRegionCodes: includedRegionCodes,
  includePureServiceAreaBusinesses: includePureServiceAreaBusinesses,
  fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
  fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
  selectionFields: selectionFields,
  selectionLanguageCode: selectionLanguageCode,
  selectionRegionCode: selectionRegionCode,
  selectionTimeZoneAt: selectionTimeZoneAt,
  selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
  fieldMode: fieldMode,
  onSelection: onSelection,
  onClearField: onClearField,
  onError: onError,
  maxSuggestions: maxSuggestions,
  enabled: enabled,
  autofocus: autofocus,
  showPoweredByGoogle: showPoweredByGoogle,
  suggestionBuilder: suggestionBuilder,
)
```

In practice:
- `fieldMode` can be `inline`, `dialog`, or `fullscreen`
- `includedPrimaryTypes` uses Google Places primary type strings such as `'restaurant'`, `'cafe'`, or `'(cities)'`
- `selectionFields` controls which fields are fetched when details loading is enabled
- `maxSuggestions` is a display cap and is effectively limited to `5` by Google Autocomplete (New)
- if you pass a custom `InputDecoration`, the package preserves your styling and still keeps the clear action available

Google primary type reference:
- [includedPrimaryTypes](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete#includedPrimaryTypes)

## Selection Model

All widget flows return a package-owned `PlaceSelection`:

```dart
class PlaceSelection {
  final PlaceSuggestion suggestion;
  final PlaceData? place;
  final PlaceTimeZoneData? timeZone;
}
```

This means:
- `suggestion` is always available
- `place` is available when `fetchPlaceDetailsOnSelection` is enabled
- `timeZone` is available when `fetchTimeZoneOnSelection` is enabled

## Standalone Client Calls

Use the client directly when you already have a place id or want to resolve
time-zone data separately from the widget flow.

Fetch rich place details from a place id:

```dart
final place = await client.fetchPlaceById(
  'ChIJmQJIxlVYwokRLgeuocVOGVU',
  fields: PlaceFieldPresets.rich,
  languageCode: 'en',
  regionCode: 'us',
);
```

Fetch time-zone data from resolved place details:

```dart
final timeZone = await client.fetchTimeZoneForPlace(
  place,
  timestamp: DateTime.now().toUtc(),
  languageCode: 'en',
);

debugPrint(timeZone.timeZoneId);
debugPrint(timeZone.timeZoneName);
```

Time-zone lookups use Google Time Zone API, which is separate from Places API
and may be billed separately.

## Typed Address Details

When you request `PlaceField.postalAddress` and/or
`PlaceField.addressComponents`, `PlaceData` exposes typed address structures
and convenience getters for common legacy-style fields:

```dart
final place = await client.fetchPlaceById(
  'ChIJmQJIxlVYwokRLgeuocVOGVU',
  fields: <PlaceField>{
    ...PlaceFieldPresets.rich,
    PlaceField.postalAddress,
    PlaceField.addressComponents,
  },
);

debugPrint(place.route);
debugPrint(place.streetNumber);
debugPrint(place.locality);
debugPrint(place.administrativeArea);
debugPrint(place.postalCode);
debugPrint(place.country);
debugPrint(place.countryCode);
```

Google references:
- [Place resource: postalAddress](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#PostalAddress)
- [Place resource: addressComponents](https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#AddressComponent)

## Overlay Usage

Use `PlacesAutocompleteOverlay.show()` when search should happen in a dedicated
route instead of inline:

```dart
final selection = await PlacesAutocompleteOverlay.show(
  context,
  client: client,
  mode: PlacesAutocompleteOverlayMode.fullscreen,
  languageCode: 'en',
  regionCode: 'us',
  fetchPlaceDetailsOnSelection: true,
  fetchTimeZoneOnSelection: true,
  selectionFields: PlaceFieldPresets.rich,
);
```

## Example App

The `/example` app demonstrates:
- inline autocomplete
- form integration
- dialog and fullscreen launcher modes
- rich place-details loading
- optional time-zone loading
- custom strings
- locale switching
- RTL layout

Run it with:

```sh
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```
