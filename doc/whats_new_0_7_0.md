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
- [Search layouts](#search-layouts)
- [Your own field, rows, and suggestion area](#your-own-field-rows-and-suggestion-area)
- [Fewer billed requests](#fewer-billed-requests)
- [`TextField` options and inline placement](#textfield-options-and-inline-placement)
- [Your own search UI with the controller](#your-own-search-ui-with-the-controller)
- [Address forms](#address-forms)
- [Entrances, navigation points, and every field at once](#entrances-navigation-points-and-every-field-at-once)
- [Place photos](#place-photos)
- [Why the `material_ui` migration exists](#why-this-release-exists)

## Apps on either design library

Flutter `3.47`'s `flutter create` still generates apps on `package:flutter/material.dart`; the next
template generates `material_ui` apps. Both kinds will be adding this package for months, and pub
cannot pick a version by design library. So `0.7.0` works in both with no app code.

In a `material_ui` app nothing changes. In an app that has not migrated, the widgets supply the
`material_ui` localizations and `Material` they need themselves, using `material_ui`'s default theme
in your app's light or dark brightness. A debug build prints a one-time note saying so. To style the
field without migrating, wrap it in `material_ui`'s `Theme`; the widgets keep a `Theme` they find
above them. To keep your app's own theme on the field, return your own `TextField` from
`fieldBuilder` — see [Your own field, rows, and suggestion area](#your-own-field-rows-and-suggestion-area)
— or migrate the app:

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

## Search layouts

All three modes were rebuilt around one rule: the field stays where the user is typing, and only the
results move.

- **Inline.** Suggestions float over the page in a raised card anchored under the field, instead of
  pushing the content below it down. The card fits in the space the keyboard and system bars leave,
  and opens above the field when there is more room there — a field near the bottom of the screen
  no longer has its suggestions hidden behind the keyboard. When five suggestions do not fit, the
  rows scroll.
- **Dialog.** The title, close button and field stay put while the results scroll beneath them,
  edge to edge across the dialog. On a screen too short for that — a phone in landscape with the
  keyboard up — the whole dialog scrolls instead.
- **Fullscreen.** The field sits in the top bar with the platform's back button, as on platform
  search screens, and the results run edge to edge below it. It opens as a regular page, so the
  Android back gesture and the iOS edge swipe close it too. The field has no border there unless
  your `decoration:` sets one, and the bar grows to fit a label or an error line. Its colours come
  from the colour scheme, not your app bar theme, so a brand-coloured app bar cannot make the
  search text unreadable.

In every mode the "Powered by Google" attribution follows a short list and stays visible beneath a
long one, so it is never scrolled away from the results. On iOS and macOS the loading indicator is
the platform's activity indicator.

Three things behave differently:

- Inline suggestions no longer take space in your layout. A screen that relied on them pushing a
  button down now has the suggestions covering it until a place is picked — see
  [MIGRATION.md](../MIGRATION.md#9-inline-suggestions-float-over-the-page).
- In fullscreen mode, `title` is no longer drawn: the field has taken its place. Screen readers
  announce it as the screen's name.
- If you mount `PlacesAutocompleteOverlay` yourself rather than calling `show()`, give it a bounded
  height, as a route or a dialog does — like Flutter's own `AlertDialog`.

## Your own field, rows, and suggestion area

Three builders replace parts of the default UI, each in every mode — inline, the dialog, and the
fullscreen search:

- **`suggestionItemBuilder`** builds each suggestion row, for places and for query suggestions. It
  gets the suggestion, whether the keyboard has highlighted it, and `onSelected`.
- **`suggestionsViewBuilder`** builds the area around the rows in each of its states — loading,
  results, empty, and error — and gets the built rows, the typed `PlacesException` when a search
  fails, `onRetry`, Google's attribution, and `defaultView`, the package's own view, to return for
  the states you keep:

  ```dart
  PlacesAutocompleteField(
    apiKey: apiKey,
    suggestionsViewBuilder: (context, view) => switch (view.status) {
      PlacesSuggestionsStatus.error
          when view.error?.kind == PlacesErrorKind.network =>
        const Card(child: ListTile(title: Text('You are offline.'))),
      _ => view.defaultView,
    },
  )
  ```

  Until now the error state showed one fixed message whatever went wrong; the view now sees why.
- **`fieldBuilder`** builds the text field. It receives only `package:flutter/widgets.dart` types,
  so it can return a `CupertinoSearchTextField`, or — in an app still on
  `package:flutter/material.dart` — that app's own `TextField` with its own theme.

Together they build a search with no Material widget in it; the
[recipes](recipes.md#a-cupertino-style-search) show a Cupertino one. For lighter changes, a
`Theme` around the field with a `listTileTheme` restyles the default rows, including the bold matched
text.

`suggestionBuilder`, which built only a place row's title, is deprecated in favour of
`suggestionItemBuilder` and will be removed in `1.0.0`. It still works; the two cannot be combined.

Fixed on the way:

- Typing the first characters showed "No matching places found." until the first response
  arrived. It now shows the loading state.
- The keyboard-highlighted row had no background, and its subtitle took the primary colour. It now
  uses the theme's focus colour, as Flutter's own `Autocomplete` does, and the text is unchanged.
- Arrow keys could move the highlight to a row scrolled out of view. The list now scrolls to it.
- Matched text in a subtitle was drawn at the title's size.
- A `Theme` around the field reached the dialog but not the fullscreen search. It now reaches both.
- Rows for the previous text could be picked with the keyboard while the next search was loading.

## Fewer billed requests

Every search the field sends is an autocomplete request Google bills. Two options on the widgets now
send fewer of them:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  minInputLength: 3,
  debounceDuration: const Duration(milliseconds: 500),
)
```

- **`minInputLength`** holds the search back until the user has typed that many characters,
  counted as the user sees them, so a letter with an accent counts once. It defaults to `1`: some
  place names are short — `北京` is two characters. Going back below the minimum closes the
  suggestions but keeps the session, so the user's next search is still part of it.
- **`debounceDuration`** is how long the field waits after the last keystroke. It used to be
  reachable only through a `PlacesAutocompleteController`; when you leave it unset, the
  controller's value, 300 ms by default, still applies.

## `TextField` options and inline placement

The widgets take `TextField`'s own options, under `TextField`'s names and with its defaults, so
swapping a `TextField` for a `PlacesAutocompleteField` keeps them. That is every option except the
few a one-line search field cannot honour — `readOnly`, `canRequestFocus`, `obscureText`,
`obscuringCharacter`, `maxLines`, `minLines`, `expands`, `restorationId`, and the deprecated
`toolbarOptions` and `scribbleEnabled` — and the ones the widget already has (`controller`,
`decoration`, `enabled`, `autofocus`). They reach the dialog and fullscreen search too:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  textCapitalization: TextCapitalization.words,
  autocorrect: false,
)
```

`keyboardType` now defaults to `TextInputType.streetAddress`, which shows a keyboard suited to
addresses on Android and asks Linux input methods to capitalize words; iOS, the web, macOS, and
Windows keep the usual text keyboard. See
[MIGRATION.md](../MIGRATION.md#10-the-keyboard-is-for-street-addresses) to keep the old one. The
options configure the package's own field; with a `fieldBuilder`, set them on yours.

Five of them run alongside what the widget does rather than replacing it: `onChanged` (typing still
searches), `onTap` (a launcher tap still opens the search), `onTapOutside` and `onTapUpOutside` (a
tap outside still does what `TextField` does by default), and `contextMenuBuilder` (your menu also
works in apps still on `package:flutter/material.dart`). `scrollController`, `undoController`,
and `statesController` attach to one field, so in dialog and fullscreen modes they go to the search
field, not the launcher. The keyboard's action button, as in
any `TextField`, gives up focus by default, which closes the suggestions; pass `onEditingComplete`
to keep them open.

Two options place an inline field's suggestions:

- **`suggestionsViewOpenDirection`** takes Flutter's own `OptionsViewOpenDirection`. The default,
  `mostSpace`, opens on the side with more room; `down` and `up` always use that side.
- **`unfocusOnSelection: false`** keeps focus in the field after a pick, so a keyboard user stays
  where they were.

To cap the suggestion area's height or put dividers between rows, wrap or rebuild the default view
in `suggestionsViewBuilder`; the
[recipes](recipes.md#customize-the-field-and-the-suggestions) show both.
`includeFutureOpeningBusinesses`, which includes places that have not opened yet, joins the widgets'
search options. And `PlaceSelection.fromPlace` turns a place fetched by its saved ID into a form
field's `initialValue`; see [Start from a saved place](recipes.md#start-from-a-saved-place).

Fixed on the way: on the web, a circle `locationRestriction` for autocomplete through the Maps
JavaScript API — which accepts only a rectangle there — was sent anyway, where Google could reject
it with an unclear error or leave the search unrestricted. It now fails with a `validation` error
that says so.

## Your own search UI with the controller

`PlacesAutocompleteController` now runs the search itself, so you can draw the field and the
suggestions yourself and still get the debounce, the minimum length, stale-result handling, and
one billing session per search:

```dart
final controller = PlacesAutocompleteController(apiKey: apiKey);

TextField(
  controller: controller.textController,
  onChanged: (_) => controller.search(),
);
ListenableBuilder(
  listenable: controller,
  builder: (context, _) => Column(
    children: [
      for (final suggestion in controller.suggestions)
        ListTile(
          title: Text(suggestion.displayText),
          onTap: () => controller.select(suggestion),
        ),
    ],
  ),
);
```

Its `suggestions`, `status`, `error`, `highlightIndex`, and `selectionLoading` are what the widgets
draw, and it notifies its listeners when they change. `select()` loads the place's details and
ends the session with that request, as the widgets do; `clear()`, `resetSession()`, and `dispose()`
end it without one. Search settings go in `PlacesAutocompleteOptions`, under the widgets' names.
Given `apiKey:`, the controller creates a client and closes it in `dispose()`; given `client:`, it
never closes it. It also takes your own `TextEditingController` and `FocusNode`.

Passed to a widget, the controller is driven by it: the widget's parameters and client apply, not
the controller's. An app that listens to its controller now hears every change to the search, not
only selection and session changes.

Fixed on the way: a widget rebuilt with a new but equal `LocationBias` or `LocationRestriction` —
`LocationBias.circle(...)` written in `build` — ended the user's session and dropped the search on
every rebuild. Both now compare by value. Only the settings that shape the autocomplete request
end a session when they change; `maxSuggestions`, `minInputLength`, and the selection settings,
such as `selectionTimeZoneAt: DateTime.now()`, apply from the next search or pick. And `selectedSelection` is now read-only — assigning it never notified anyone;
see [MIGRATION.md](../MIGRATION.md#11-selectedselection-is-read-only).

Fixed on the way: in `PlacesAutocompleteFormField`, typing after picking a place emptied the field
— the form followed the controller in clearing its value, and then put that empty value back into
the text. Typing now keeps the text and clears only the value.

Also fixed: `FormState.reset()` left text the user had typed without picking a place, since the
form value was empty before and after. A reset now puts back the `initialValue`'s text, or clears
the field, and ends the search and its billing session without a details request.

`searchOnQuerySelection: true` makes picking a query suggestion search for that phrase at once, in
a new session, so the user can pick a place from the results — in every field mode, on the form
field, and through `show()`. Picking a query suggestion also now ends the session *before*
`onQuerySelection` is called, so a controller's `search()` called from there searches in a new
session too; see the [recipe](recipes.md#search-again-with-a-picked-query-suggestion).

## Address forms

One pick can fill the rest of an address form — street, city, region, postal code, country — with
the address getters, set in `onSelection` and emptied in `onClearField`:

```dart
PlacesAutocompleteFormField(
  apiKey: apiKey,
  includedPrimaryTypes: PlaceTypePresets.address,
  onSelection: (selection) {
    city.text = selection.place?.city ?? '';
    postalCode.text = selection.place?.postalCode ?? '';
  },
  onClearField: () {
    city.clear();
    postalCode.clear();
  },
)
```

The full version is the [address-form recipe](recipes.md#fill-an-address-form). `onClearField` is
called when the user clears the field or types over the pick. In dialog and fullscreen field
modes, clearing inside the search used to report the pick gone while the field went on showing it
once the search closed; the field now clears too.

`PlaceTypePresets` names the `includedPrimaryTypes` values most searches want, so there are no
strings like `'(cities)'` to look up:

| Preset | Sends |
| --- | --- |
| `cities` | `(cities)` |
| `regions` | `(regions)` |
| `postalCode` | `postal_code` |
| `address` | `street_address`, `premise`, `subpremise` |
| `establishment` | `establishment` |

They are plain lists of Google's type names, so the last three combine with each other and with
your own types: `[...PlaceTypePresets.address, ...PlaceTypePresets.postalCode]`.

## Entrances, navigation points, and every field at once

`PlaceField.entrances` and `PlaceField.navigationPoints` request two fields Google added in August
2026: where a place's entrances are, and the points next to a road where navigation to it can end.
Both are Place Details Pro fields, and both arrive as read-only JSON on `PlaceData.entrances` and
`PlaceData.navigationPoints`:

```dart
final place = await client.fetchPlaceById(
  placeId,
  fields: {...PlaceFieldPresets.address, PlaceField.entrances},
);
for (final entrance in place.entrances) {
  debugPrint('${entrance['location']} ${entrance['tags']}');
}
```

The Maps JavaScript `Place` class does not have them, so on the web a request for either one falls
back to the HTTP path, which `PlacesWebFallbackPolicy` must allow.

`PlaceFieldPresets.all` is every `PlaceField` the package supports, built from `PlaceField.values`.
It is for exploring what Google returns and for admin tools, **not** for production autocomplete:
it always bills at the highest tier, Enterprise + Atmosphere, on Place Details, Text Search and
Nearby Search; it returns the largest responses; and it grows when a package version adds fields,
so a request that uses it can bill differently after an upgrade. On the web it takes the HTTP path
for the same reason as the two new fields.

## Place photos

`PlacePhotoView` shows a photo from a place result. Request `PlaceField.photos`, then:

```dart
PlacePhotoView(photo: place.photos.first, apiKey: apiKey, height: 200)
```

Before, showing a photo meant calling `fetchPhotoMedia` for its address, loading that address into
an `Image`, and placing `PlacesPhotoAttribution` beside it — and getting cancellation, stale results
and sizing right by hand. The widget does all of it:

- **Size.** `width` and `height` are logical pixels; the widget requests that size times the device
  pixel ratio, rounded up and capped at Google's 4800. `maxWidthPx` / `maxHeightPx` set the request
  directly. With no size, it requests the photo's own width, so pass one for a thumbnail.
- **Fetching.** One billed Place Photos request when the widget is built, and again only when the
  photo, the client or the requested size changes. A fetch still running is cancelled when the
  widget goes away, and an answer for a photo it no longer shows is dropped.
- **Attribution.** The author's name is drawn over the bottom of the image. There is no option to
  hide it: Google requires the author to be credited wherever the photo is shown.
- **Your own look.** `builder` gets the state (`loading`, `loaded`, `error`), the image, the typed
  `PlacesException`, a retry callback, the attribution to place, and the package's `defaultView`.

Two things the widget cannot do for you. Google's policies ask that users can open each photo on
Google Maps through `PlacePhoto.googleMapsUri`, and the package does not open links — add one, as
the [recipe](recipes.md#link-to-the-photo-on-google-maps) shows. And the image is downloaded by
Flutter's image loader straight from the address Google returned: with `PlacesClient.proxy()`, the
photo's address goes through your proxy, but the image does not. On web the address lookup is a REST
request, so with `apiKey:` the key is sent from the browser — pass a proxy `client:` to avoid it.

"Photo by" is now `PlacesStrings.photoAttributionPrefix`, shared by `PlacePhotoView` and
`PlacesPhotoAttribution`. `PlacesPhotoAttribution`'s own `prefix` still works and is deprecated,
for removal in `1.0.0`.

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
