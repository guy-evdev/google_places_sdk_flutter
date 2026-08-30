# What's new in 0.7.0

`0.7.0` does one thing: it moves the widget layer off `package:flutter/material.dart` and onto the
standalone [`material_ui`](https://pub.dev/packages/material_ui) package. There are no new options,
no bug fixes, and no other changes. If you need to bisect something in this release, there is only
one candidate.

The step-by-step upgrade is in [MIGRATION.md](../MIGRATION.md#070). This page explains what changed
and why.

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

`material_ui` `1.1.0` declares `sdk: ^3.12.0` and `flutter: ">=3.44.0"`, so this package cannot
promise less. The floor went from Flutter `3.35.0` to `3.44.0` — nine minor versions — and that is
the real cost of this release.

The floor is `3.44.0` rather than `3.47.0` deliberately. Flutter `3.44.0` ships Dart `3.12.0`,
which is exactly `material_ui`'s minimum, so `>=3.44.0` is a measured floor rather than a guess.
Stable went `3.44.8` → `3.47.0` with no `3.45` or `3.46` in between, so flooring at `3.47.0` would
have dropped the entire `3.44.x` line for no benefit. `material_ui` was verified to resolve, analyze,
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

The direct dependency list is now `http`, `web`, and `material_ui`. `material_ui` brings
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
