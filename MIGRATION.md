# Migration guide

Upgrades that require source changes, newest first. Releases not listed here need no source
changes.

## 0.7.0

`0.7.0` moves the widget layer from the in-framework `package:flutter/material.dart` to the
standalone [`material_ui`](https://pub.dev/packages/material_ui) package, following Flutter's own
Material and Cupertino decoupling. It also changes defaults: a selection now carries coordinates
and an address, and `PlacesClient` requests fewer fields when you pass none.

| If your app… | Do |
| --- | --- |
| Uses `material_ui`, or is migrating to it | Steps 1, 2, 4, 5, and 6 if you build localization delegates |
| Still uses `package:flutter/material.dart` | Steps 1, 4, and 5; step 3 if you pass `decoration:` |
| Reads `PlacesAutocompleteField.client` or `PlacesAutocompleteOverlay.client` | Step 7 |
| Calls `PlacesClient` for details or search without passing `fields:` | Step 8 |
| Has an inline field with a control just below it | Step 9 |
| Wants the plain text keyboard on Android | Step 10 |
| Assigns `PlacesAutocompleteController.selectedSelection` | Step 11 |
| Reads `PlacesPhotoAttribution.prefix` | Step 12 |
| Builds for web with `flutter build web --wasm` | Step 13 |

### 1. Raise your SDK floor

`material_ui` requires Dart `^3.12.0` and Flutter `>=3.44.0`, so this package now does too.

```yaml
# Before
environment:
  sdk: ">=3.9.0 <4.0.0"
  flutter: ">=3.35.0"

# After
environment:
  sdk: ">=3.12.0 <4.0.0"
  flutter: ">=3.44.0"
```

### 2. In a `material_ui` app: take `InputDecoration` from `material_ui`

`material_ui`'s `InputDecoration` is a different type from `package:flutter/material.dart`'s, and
`MaterialUiCompatibilityBridge` cannot bridge a type in a public API signature. Upgrade this
package and migrate your app in the same step. Flutter ships an automated fix — run it in your
app, then review the result:

```shell
dart fix --apply --code=migrate_design_widgets
```

It rewrites imports only:

```dart
// Before
import 'package:flutter/material.dart';

// After
import 'package:material_ui/material_ui.dart';
```

and needs `material_ui` in your app's own dependencies:

```yaml
dependencies:
  google_places_sdk_flutter: ^0.7.0
  material_ui: ^1.1.0
```

Do not add `cupertino_ui` unless your own code imports it. Four public surfaces accept an
`InputDecoration`; the parameter names are unchanged:

| Surface | Parameter |
| --- | --- |
| `PlacesAutocompleteField` | `decoration` |
| `PlacesAutocompleteOverlay` | `decoration` |
| `PlacesAutocompleteOverlay.show()` | `decoration:` |
| `PlacesAutocompleteFormField` | `decoration:` |

### 3. In an app still on `package:flutter/material.dart`: only `decoration:` changes

The widgets work with no code change: they supply what `material_ui` needs themselves and use its
default theme, following your app's brightness. Only a `decoration:` must now be `material_ui`'s
`InputDecoration`. Add `material_ui` to your dependencies as in step 2, and import it with a prefix
in the files that build one:

```dart
// Before
import 'package:flutter/material.dart';

PlacesAutocompleteField(
  client: client,
  decoration: const InputDecoration(labelText: 'Choose a place'),
);

// After
import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui;

PlacesAutocompleteField(
  client: client,
  decoration: const mui.InputDecoration(labelText: 'Choose a place'),
);
```

To style the field without migrating, wrap it in `material_ui`'s `Theme`. To get your app's own
theme on it, migrate the app (step 2).

### 4. Place details now load on selection

`fetchPlaceDetailsOnSelection` defaults to `true`, so `selection.place` is filled in. Each completed
selection now makes one Place Details request, which also ends the user's autocomplete session —
how Google prices sessions. With the default fields it is billed as Place Details Essentials.

If you resolved the place yourself, or only need the place ID, opt out:

```dart
// Before — details were off by default
PlacesAutocompleteField(
  client: client,
  onSelection: (selection) => lookUp(selection.placeId),
);

// After — keep them off
PlacesAutocompleteField(
  client: client,
  fetchPlaceDetailsOnSelection: false,
  onSelection: (selection) => lookUp(selection.placeId),
);
```

### 5. The default selection fields are `PlaceFieldPresets.address`

`selectionFields` defaults to `PlaceFieldPresets.address` — `id`, `formattedAddress`,
`shortFormattedAddress`, `location`, and `addressComponents`, all Essentials. The old default,
`PlaceFieldPresets.recommended`, also returned `displayName`, `primaryType`, `googleMapsUri`,
`rating`, and others, which Google bills as Pro and Enterprise. If you read any of those, ask for
them explicitly:

```dart
// Before — recommended was the default
PlacesAutocompleteField(
  client: client,
  fetchPlaceDetailsOnSelection: true,
  onSelection: (selection) => show(selection.place?.rating),
);

// After
PlacesAutocompleteField(
  client: client,
  selectionFields: PlaceFieldPresets.recommended,
  onSelection: (selection) => show(selection.place?.rating),
);
```

The place's name is still available without `displayName`, as
`selection.suggestion.primaryText.text`.

### 6. If you use localization delegates

`GlobalMaterialLocalizations` now comes from `material_ui` rather than `flutter_localizations`,
and `GlobalMaterialLocalizations.delegates` replaces the three-delegate list.

```dart
// Before
import 'package:flutter_localizations/flutter_localizations.dart';

MaterialApp(
  localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  // ...
);

// After
import 'package:material_ui/material_ui.dart';

MaterialApp(
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  // ...
);
```

A direct `flutter_localizations` dependency is no longer required for this; `material_ui` depends
on it. Remove it only if nothing else in your app imports it.

### 7. `client` is nullable on the field and overlay widgets

The widgets now accept `apiKey:` as an alternative to `client:`, so the `client` field they expose
is `PlacesClient?`. Constructing the widgets is unchanged. Code that reads the field needs a null
check:

```dart
// Before
final client = field.client;

// After
final client = field.client!; // non-null whenever the widget was given a client
```

### 8. `PlacesClient` requests fewer fields by default

`fetchPlaceById` and `PlaceDetailsRequest` default to `PlaceFieldPresets.address`, billed as Place
Details Essentials. `TextSearchRequest` and `NearbySearchRequest` default to
`PlaceFieldPresets.minimal` — `id`, `displayName`, `formattedAddress`, and `location` — billed as
Pro. All four used to default to `PlaceFieldPresets.recommended`, which includes `rating` and
`userRatingCount` and is billed as Enterprise.

A call that passes `fields:` is unchanged. A call that relied on the default no longer receives
`primaryType`, `primaryTypeDisplayName`, `googleMapsUri`, `rating`, `userRatingCount`, or the icon
fields, and Place Details no longer receives `displayName`. If you read any of them, ask for them:

```dart
// Before — recommended was the default
final place = await client.fetchPlaceById(placeId);
final results = await client.searchText(
  const TextSearchRequest(textQuery: 'coffee'),
);

// After
final place = await client.fetchPlaceById(
  placeId,
  fields: PlaceFieldPresets.recommended,
);
final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee',
    fields: PlaceFieldPresets.recommended,
  ),
);
```

### 9. Inline suggestions float over the page

An inline `PlacesAutocompleteField` used to grow while it showed suggestions, pushing the content
below it down. The suggestions now float over that content, anchored to the field, and open above
it when the keyboard leaves more room there. Most screens need no change. If something below the
field must stay visible while the user types, search on a separate surface instead:

```dart
// Before — the suggestions pushed the button below the field down
Column(
  children: <Widget>[
    PlacesAutocompleteField(apiKey: apiKey, onSelection: onSelection),
    FilledButton(onPressed: submit, child: const Text('Continue')),
  ],
)

// After — the field opens a fullscreen search, and the button never moves
Column(
  children: <Widget>[
    PlacesAutocompleteField(
      apiKey: apiKey,
      fieldMode: PlacesAutocompleteFieldMode.fullscreen,
      onSelection: onSelection,
    ),
    FilledButton(onPressed: submit, child: const Text('Continue')),
  ],
)
```

To keep inline suggestions below the field even when there is more room above it, pass
`suggestionsViewOpenDirection: OptionsViewOpenDirection.down`.

### 10. The keyboard is for street addresses

The widgets now ask for `TextInputType.streetAddress`. On Android that shows a keyboard suited to
addresses, and on Linux it asks the input method to capitalize words; on iOS, the web, macOS, and
Windows the keyboard is unchanged. To keep the plain text keyboard:

```dart
// Before — the plain text keyboard was the default
PlacesAutocompleteField(apiKey: apiKey)

// After
PlacesAutocompleteField(
  apiKey: apiKey,
  keyboardType: TextInputType.text,
)
```

### 11. `selectedSelection` is read-only

`PlacesAutocompleteController.selectedSelection` was a public field, and assigning it skipped
notifying the controller's listeners. It is now a getter. Use the method for what you meant:

```dart
// Before
controller.selectedSelection = selection;
controller.selectedSelection = null;

// After
controller.setSelection(selection); // also puts its text in the field
controller.setSelection(selection, updateText: false); // keeps the text
controller.restoreSelection(selection); // a saved value, with its text
controller.clearSelection();
```

### 12. `PlacesPhotoAttribution.prefix` is nullable and deprecated

The "Photo by" text moved to `PlacesStrings.photoAttributionPrefix`, shared with `PlacePhotoView`.
`prefix` still works, but it is now `null` unless you set it:

```dart
// Before
PlacesPhotoAttribution(photo: photo, prefix: 'Photo de')
final String text = attribution.prefix;

// After
PlacesPhotoAttribution(
  photo: photo,
  strings: const PlacesStrings(photoAttributionPrefix: 'Photo de'),
)
final String text = attribution.strings.photoAttributionPrefix;
```

### 13. Wasm web builds use the Maps JavaScript API

Through `0.6.x`, an app built with `flutter build web --wasm` used the package's REST backend and
ignored `PlacesWebOptions.fallbackPolicy`. From `0.7.0` it uses the same web backend as a
JavaScript web build: autocomplete and place details go through the Maps JavaScript API, and the
fallback policy applies. In the Google Cloud console:

- Enable the **Maps JavaScript API** for the key the app uses on web.
- If the key has website restrictions, keep your site listed — the Maps JavaScript API checks them.

Until it is enabled, the browser console shows `ApiNotActivatedMapError` and no suggestions load.

The web backend also refuses three things the REST backend accepted, so a Wasm build that used them
now fails with a `PlacesException`:

```dart
// Before — accepted by 0.6.x Wasm builds
final client = PlacesClient(
  apiKey: apiKey,
  httpClient: myHttpClient,
  options: PlacesClientOptions(applicationIdentity: identity),
);
PlacesAutocompleteField(
  client: client,
  locationRestriction: LocationRestriction.circle(center: center, radiusMeters: 5000),
);

// After — on web, no injected HTTP client or application identity, and a rectangle
final client = PlacesClient(
  apiKey: apiKey,
  httpClient: kIsWeb ? null : myHttpClient,
  options: PlacesClientOptions(applicationIdentity: kIsWeb ? null : identity),
);
PlacesAutocompleteField(
  client: client,
  locationRestriction: LocationRestriction.rectangle(low: southWest, high: northEast),
);
```

Every client on a page also needs the same key: the Maps JavaScript API loads once per page, so a
second client with a different key fails with `conflicting_javascript_api_key`.
