# Google Places SDK Flutter

[![pub package](https://img.shields.io/pub/v/google_places_sdk_flutter.svg)](https://pub.dev/packages/google_places_sdk_flutter)
[![CI](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/guy-evdev/google_places_sdk_flutter/actions/workflows/ci.yml)

Cross-platform Google Places client and widget toolkit for Flutter, built on
Places API (New). The package includes typed request/response models, a
cross-platform `PlacesClient`, and autocomplete widgets for inline, form,
dialog, and fullscreen flows.

## Contents

- [Preview](#preview)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Client APIs](#client-apis)
- [Options](#options)
- [Example App](#example-app)
- [API Reference](#api-reference)

## Preview

<p>
  <img src="https://raw.githubusercontent.com/guy-evdev/google_places_sdk_flutter/main/assets/readme/example.gif" alt="Package example" width="320" />
</p>

## Features

- Places API (New) autocomplete with optional query predictions
- Optional place-details and Google Time Zone API lookup on selection
- Place Photos (New) media URI lookup
- Text search and nearby search client APIs
- Inline, form, dialog, and fullscreen autocomplete UI
- Locale support with `languageCode`, `regionCode`, custom strings, and RTL
- Field-mask control through `PlaceField` and `PlaceFieldPresets`
- Typed address support and typed-light access to newer Places fields

## Installation

Add the package to your `pubspec.yaml` file:

```yaml
dependencies:
  google_places_sdk_flutter: latest_version
```

Create a client with your Google Maps Platform API key:

```dart
final client = PlacesClient(
  apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
);
```

On web, the package uses the Google Maps JavaScript Places library behind the
same `PlacesClient` API.

Official Google docs:
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service)
- [Place Autocomplete (New)](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete)
- [Place Details (New)](https://developers.google.com/maps/documentation/places/web-service/place-details)
- [Time Zone API](https://developers.google.com/maps/documentation/timezone/requests-timezone)

## Quick Start

```dart
import 'package:flutter/material.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

class PlacesSearchField extends StatefulWidget {
  const PlacesSearchField({super.key});

  @override
  State<PlacesSearchField> createState() => _PlacesSearchFieldState();
}

class _PlacesSearchFieldState extends State<PlacesSearchField> {
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
      decoration: const InputDecoration(
        labelText: 'Place',
        border: OutlineInputBorder(),
      ),
      languageCode: 'en',
      regionCode: 'us',
      fetchPlaceDetailsOnSelection: true,
      selectionFields: PlaceFieldPresets.recommended,
      onSelection: (selection) {
        debugPrint(selection.displayText);
        debugPrint(selection.place?.formattedAddress);
      },
    );
  }
}
```

For form validation, use `PlacesAutocompleteFormField`. For a dedicated search
surface, use `PlacesAutocompleteOverlay.show()` with `dialog` or `fullscreen`
mode.

## Client APIs

Use `autocomplete()` for place-only autocomplete results:

```dart
final places = await client.autocomplete(
  const AutocompleteRequest(input: 'coffee'),
);
```

Use `autocompleteSuggestions()` when you want query predictions as well:

```dart
final suggestions = await client.autocompleteSuggestions(
  const AutocompleteRequest(
    input: 'coffee',
    includeQueryPredictions: true,
  ),
);

for (final suggestion in suggestions) {
  switch (suggestion) {
    case PlaceSuggestion():
      debugPrint('Place: ${suggestion.placeId}');
    case QuerySuggestion():
      debugPrint('Query: ${suggestion.displayText}');
  }
}
```

Fetch details, time-zone data, search results, or photo media directly:

```dart
final place = await client.fetchPlaceById(
  'ChIJmQJIxlVYwokRLgeuocVOGVU',
  fields: PlaceFieldPresets.rich,
);

final timeZone = await client.fetchTimeZoneForPlace(place);

final results = await client.searchText(
  const TextSearchRequest(textQuery: 'coffee near me'),
);

final media = await client.fetchPhotoMedia(
  PhotoMediaRequest(
    name: place.photos.first.name,
    maxWidthPx: 800,
  ),
);
```

## Options

Common widget options:

| Option | Default | Use when |
| --- | --- | --- |
| `fieldMode` | `PlacesAutocompleteFieldMode.inline` | You want inline, dialog, or fullscreen search UI. |
| `languageCode` | `null` | You want localized results. |
| `regionCode` | `null` | You want region-aware ranking/formatting. |
| `locationBias` | `null` | You prefer results near an area without excluding others. |
| `locationRestriction` | `null` | You only want results inside an area. |
| `includedPrimaryTypes` | `const <String>[]` | You want types such as `restaurant`, `cafe`, or `(cities)`. |
| `fetchPlaceDetailsOnSelection` | `false` | You need `PlaceData` after selection. |
| `fetchTimeZoneOnSelection` | `false` | You need time-zone metadata after selection. |
| `selectionFields` | `PlaceFieldPresets.recommended` | You want to control Place Details payload size. |
| `includeQueryPredictions` | `false` | You want suggested search phrases alongside places. |
| `maxSuggestions` | `5` | You want to display fewer than Google's five suggestions. |
| `showPoweredByGoogle` | `true` | You want the package to render Google attribution. |

`locationBias` and `locationRestriction` cannot be used together. Query
predictions are additive; keep place predictions for flows where users must
select a concrete place id.

## Example App

The `/example` app demonstrates inline autocomplete, form integration, dialog
and fullscreen launchers, query predictions, rich place-details loading,
optional time-zone loading, custom strings, locale switching, and RTL layout.

Run it with:

```sh
flutter run --dart-define=GOOGLE_MAPS_API_KEY=your_key_here
```

## API Reference

See [doc/api_reference.md](doc/api_reference.md) for:

- Full widget, overlay, client, and request defaults
- `PlaceField` API names
- `PlaceFieldPresets.minimal`, `recommended`, and `rich` membership
