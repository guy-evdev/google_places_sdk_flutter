# Migration guide

Upgrades that require source changes, newest first. Releases not listed here need no source
changes.

## 0.7.0

`0.7.0` moves the widget layer from the in-framework `package:flutter/material.dart` to the
standalone [`material_ui`](https://pub.dev/packages/material_ui) package, following Flutter's own
Material and Cupertino decoupling.

**You must migrate your own app in the same step.** The class names are unchanged, but
`material_ui`'s `InputDecoration` is a different type from `package:flutter/material.dart`'s
`InputDecoration`, and `MaterialUiCompatibilityBridge` cannot bridge a type mismatch in a public
API signature. Upgrading this package without migrating your app will not compile, and migrating
your app without upgrading this package will not compile either.

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

### 2. Add `material_ui` to your app

```yaml
# Before
dependencies:
  flutter:
    sdk: flutter
  google_places_sdk_flutter: ^0.6.1

# After
dependencies:
  flutter:
    sdk: flutter
  google_places_sdk_flutter: ^0.7.0
  material_ui: ^1.1.0
```

Do not add `cupertino_ui` unless your own code imports it. `material_ui` depends on it and brings
it in transitively.

### 3. Rewrite your imports

Flutter ships an automated fix for this. Run it in your app, then review the result:

```shell
dart fix --apply --code=migrate_design_widgets
```

It rewrites imports only. It does not reason about public API, so check anything it did not touch.

```dart
// Before
import 'package:flutter/material.dart';

// After
import 'package:material_ui/material_ui.dart';
```

### 4. Take `InputDecoration` from `material_ui`

Four public surfaces accept an `InputDecoration`. The parameter names and defaults are unchanged —
only the library the type comes from has changed.

| Surface | Parameter |
| --- | --- |
| `PlacesAutocompleteField` | `decoration` |
| `PlacesAutocompleteOverlay` | `decoration` |
| `PlacesAutocompleteOverlay.show()` | `decoration:` |
| `PlacesAutocompleteFormField` | `decoration:` |

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

### 5. If you use localization delegates

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

### What did not change

No parameter was renamed, removed, or given a new default. No behaviour changed. If your app
already compiled against `0.6.1`, the migration above is the entire change.
