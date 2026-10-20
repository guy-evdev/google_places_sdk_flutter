# What's new in 0.7.0

`0.7.0` moves the widget layer off `package:flutter/material.dart` and onto the standalone
[`material_ui`](https://pub.dev/packages/material_ui) package — and keeps the widgets working in apps
that have not made that move. It also makes the first five minutes shorter: the widgets take an
`apiKey:`, and a pick now returns coordinates and a parsed address.

The step-by-step upgrade is in [MIGRATION.md](../MIGRATION.md#070). This page explains what changed
and why.

- [Apps on either design library](#apps-on-either-design-library)
- [`apiKey:` on the widgets](#apikey-on-the-widgets)
- [Coordinates and an address by default](#coordinates-and-an-address-by-default)
- [Fewer `PlacesClient` fields by default](#fewer-placesclient-fields-by-default)
- [More address getters](#more-address-getters)
- [Why the `material_ui` migration exists](#why-this-release-exists)

## Apps on either design library

Flutter `3.47`'s `flutter create` still generates apps on `package:flutter/material.dart`; the next
template generates `material_ui` apps. Both kinds will be adding this package for months, and pub
cannot pick a version by design library. So `0.7.0` works in both with no app code.

In a `material_ui` app nothing changes. In an app that has not migrated, the widgets supply the
`material_ui` localizations and `Material` they need themselves, using `material_ui`'s default theme
in your app's light or dark brightness. A debug build prints a one-time note saying so. To style the
field without migrating, wrap it in `material_ui`'s `Theme`; the widgets keep a `Theme` they find
above them. To get your app's own theme on the field, migrate the app:

```shell
dart fix --apply --code=migrate_design_widgets
```

That covers the field, the form field, the long-press text menu, dialog and fullscreen modes,
`PlacesAutocompleteOverlay.show()` called from an unmigrated screen, and `PlacesPhotoAttribution`.
An app locale that `material_ui` does not translate falls back to English labels rather than
failing. The one thing such an app must
change is a `decoration:`, which has to be `material_ui`'s `InputDecoration` — see
[MIGRATION.md](../MIGRATION.md#070).

## `apiKey:` on the widgets

```dart
PlacesAutocompleteField(
  apiKey: const String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
  onSelection: (selection) => debugPrint(selection.place?.formattedAddress),
)
```

`PlacesAutocompleteField`, `PlacesAutocompleteFormField`, `PlacesAutocompleteOverlay`, and
`PlacesAutocompleteOverlay.show()` accept `apiKey:` as an alternative to `client:`. Pass exactly
one. Given a key, the widget creates its own `PlacesClient`, keeps it across rebuilds, replaces it
when the key changes, and closes it when the widget is disposed — or, for `show()`, once the
overlay has closed.

Keep using `client:` to share one client across screens, for `PlacesClient.proxy()`, or for a key
restricted to your Android or iOS app: a client made from `apiKey:` uses default options, so it
sends no `PlacesApplicationIdentity`.

## Coordinates and an address by default

`fetchPlaceDetailsOnSelection` now defaults to `true`, and `selectionFields` to the new
`PlaceFieldPresets.address`:

| Field | Google billing tier |
| --- | --- |
| `id` | Essentials (IDs Only) |
| `formattedAddress` | Essentials |
| `shortFormattedAddress` | Essentials |
| `location` | Essentials |
| `addressComponents` | Essentials |

Google bills a Place Details request at the highest tier of any field in it, so the default pick is
billed as Place Details Essentials — the lowest tier that returns an address. The old details
default, `PlaceFieldPresets.recommended`, includes `displayName`, `primaryType`, and `googleMapsUri`
(Pro) and `rating` and `userRatingCount` (Enterprise), so turning it on by default would have billed
every pick at Enterprise. Google's
[session pricing](https://developers.google.com/maps/documentation/places/web-service/session-pricing)
goes further: a session ended by a Pro or Enterprise details request is billed at Enterprise +
Atmosphere, whatever fields it asked for, though its autocomplete requests are then free.

What this means for the bill: the details request ends the user's autocomplete session, which is how
Google prices sessions. Before, with details off, a session was never ended, so Google billed every
autocomplete request on its own. Now each completed pick adds one Essentials details request, and
autocomplete requests beyond the twelfth in a session are free.

The package's tests check the field mask on the actual request against those five names, so a
future change to the preset cannot silently move picks to a pricier tier.

`displayName` is not in the default. The name the user picked is still at
`selection.suggestion.primaryText.text`.

## Fewer `PlacesClient` fields by default

The client's own calls follow the same reasoning. When you pass no `fields:`:

| Call | Default fields | Billed as |
| --- | --- | --- |
| `fetchPlaceById`, `PlaceDetailsRequest` | `PlaceFieldPresets.address` | Place Details Essentials |
| `TextSearchRequest` | `PlaceFieldPresets.minimal` | Text Search Pro |
| `NearbySearchRequest` | `PlaceFieldPresets.minimal` | Nearby Search Pro |

All four used to default to `PlaceFieldPresets.recommended`, billed as Enterprise because it
includes `rating` and `userRatingCount`. `minimal` — `id`, `displayName`, `formattedAddress`, and
`location` — is the cheapest set that still names each search result; Nearby Search has no tier
below Pro. The package sends exactly the fields you ask for, so a call that passes `fields:` is
billed exactly as before. One exception to "fewer fields, lower tier": a Place Details request that
ends an autocomplete session at Essentials leaves the session's first 12 autocomplete requests
billed, where one above Essentials is billed at Enterprise + Atmosphere and makes them free — so a
long session is not automatically cheaper. See the README's
[Costs](../README.md#costs). To keep the old fields, pass `fields: PlaceFieldPresets.recommended` —
see [MIGRATION.md](../MIGRATION.md#070), step 8.

As with the widgets, the tests check the field mask sent by each of the four calls against literal
field names.

## More address getters

`PlaceData` already flattened `locality`, `postalCode`, `country`, and others. `0.7.0` adds:

| Getter | From |
| --- | --- |
| `city`, `cityShort` | `locality`, falling back to `postal_town`, `sublocality_level_1`, then `administrative_area_level_3` |
| `streetAddress` | `street_number` and `route`, in the order `formattedAddress` uses — `151 Broadway`, `Unter den Linden 77` |
| `county`, `countyShort` | `administrative_area_level_2` |
| `neighborhood`, `neighborhoodShort` | `neighborhood` |
| `unit` | `subpremise` |
| `postalCodeSuffix` | `postal_code_suffix` |

Use `city` rather than `locality` to fill a "City" field: UK addresses usually have a postal town
and no locality.

## Why this release exists

Flutter `3.47` published `material_ui` and `cupertino_ui` `1.0`, decoupling the Material and
Cupertino design systems from the core SDK. The in-framework libraries still ship, and Flutter
provides `MaterialUiCompatibilityBridge` so that unmigrated dependencies keep working.

The bridge has one documented limit: it cannot reconcile a type mismatch when a dependency exposes
an in-framework type in its **public API signature**. This package did exactly that — `InputDecoration`
appears in four public parameters. So the moment you ran Flutter's own migration command on your
app:

```shell
dart fix --apply --code=migrate_design_widgets
```

…your app's `InputDecoration` became `material_ui`'s, this package's stayed in-framework, and the
two no longer matched. There was no partial degradation and no workaround short of reverting your
own migration. That is why this jumped ahead of the widget milestone that was next in line.

## What changed in your code

The class names are identical. Only the library they come from moved.

```dart
// Before
import 'package:flutter/material.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

PlacesAutocompleteField(
  client: client,
  decoration: const InputDecoration(
    labelText: 'Choose a place',
    border: OutlineInputBorder(),
  ),
  onSelection: (selection) => debugPrint(selection.displayText),
);

// After
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:material_ui/material_ui.dart';

PlacesAutocompleteField(
  client: client,
  decoration: const InputDecoration(
    labelText: 'Choose a place',
    border: OutlineInputBorder(),
  ),
  onSelection: (selection) => debugPrint(selection.displayText),
);
```

The four public surfaces that take an `InputDecoration`:

| Surface | Parameter |
| --- | --- |
| `PlacesAutocompleteField` | `decoration` |
| `PlacesAutocompleteOverlay` | `decoration` |
| `PlacesAutocompleteOverlay.show()` | `decoration:` |
| `PlacesAutocompleteFormField` | `decoration:` |

Every other public type in this package comes from `package:flutter/widgets.dart`,
`painting`, `services`, or `foundation` — `TextEditingController`, `FocusNode`, `TextStyle`,
`Widget`, `FormField`, `AutovalidateMode` — and none of those moved. Nothing else in the public API
is affected.

## Why the Flutter floor moved to 3.44.0

`material_ui` `1.0.0` declares `sdk: ^3.12.0` and `flutter: ">=3.44.0"`, so this package cannot
promise less. The floor went from Flutter `3.35.0` to `3.44.0` — nine minor versions — and that is
the real cost of this release.

The floor is `3.44.0` rather than `3.47.0` deliberately. Flutter `3.44.0` ships Dart `3.12.0`,
which is exactly `material_ui`'s minimum, so `>=3.44.0` is a measured floor rather than a guess.
Stable went from `3.44` to `3.47.0` with no `3.45` or `3.46` in between, so flooring at `3.47.0`
would have dropped the entire `3.44.x` line for no benefit. `material_ui` was verified to resolve, analyze,
and pass the full test suite on Flutter `3.44.0` exactly, not merely on a newer `3.44` patch.

## Localization delegates

If your app builds a `localizationsDelegates` list by hand, `GlobalMaterialLocalizations` now comes
from `material_ui`, and the new `GlobalMaterialLocalizations.delegates` collapses the usual three
entries into one:

```dart
// Before
localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],

// After
localizationsDelegates: GlobalMaterialLocalizations.delegates,
```

The example app dropped its direct `flutter_localizations` dependency as a result; `material_ui`
depends on it, so it is still in the graph. Broader localization work is a later release, not this
one.

## Dependencies

The direct dependency list is now `http`, `web`, and `material_ui`. Each floor is the oldest version
the full test suite passes against: `http` `^1.5.0` (was `^1.6.0`; request aborting, which
cancellation needs, arrived in `1.5.0`), `web` `^1.0.0` (was `^1.1.1`), and `material_ui` `^1.0.0`.
Apps that must stay on older `http` or `web` releases can now resolve this package. `material_ui` brings
`cupertino_ui`, `intl`, `material_color_utilities`, `vector_math`, `collection`, and
`flutter_localizations` transitively.

`cupertino_ui` is **not** a direct dependency and should not be added to your app unless your own
code imports it. This package uses no Cupertino symbol.

Every dependency in the graph is either `http`/`web` or first-party `flutter.dev`. The package still
pulls in no third-party runtime stack.

## Versioning

Flutter's guide tells package authors to treat this as a major version bump. Under `0.x` semver the
minor bump **is** the major bump: `^0.6.1` does not resolve to `0.7.0`, so existing consumers are
not upgraded without opting in. No `1.0.0` is implied.

This release also breaks the project's usual rule that public signatures stay source-compatible
through `0.x`. That was a deliberate call. The alternative was not "no break" — it was "silently
broken for every user who follows Flutter's migration instructions, with no version number saying
so".
