# Recipes

Task-by-task guides for `google_places_sdk_flutter`, beyond the
[README](../README.md)'s quick start. Every option and default is in the
[API reference](api_reference.md).

- [Use the field inside a Form](#use-the-field-inside-a-form)
- [Fill an address form](#fill-an-address-form)
- [Search in a dialog or on a full screen](#search-in-a-dialog-or-on-a-full-screen)
- [Change or translate the widget's text](#change-or-translate-the-widgets-text)
- [Limit results to an area](#limit-results-to-an-area)
- [Get a place's time zone](#get-a-places-time-zone)
- [Customize the field and the suggestions](#customize-the-field-and-the-suggestions)
- [Search without a widget](#search-without-a-widget)
- [Build your own autocomplete UI](#build-your-own-autocomplete-ui)
- [Show the distance from the user's location](#show-the-distance-from-the-users-location)
- [Display photo attribution](#display-photo-attribution)
- [Cancel work that is no longer needed](#cancel-work-that-is-no-longer-needed)
- [Secure proxy and platform identity](#secure-proxy-and-platform-identity)
- [Typed errors and HTTP ownership](#typed-errors-and-http-ownership)
- [Common widget options](#common-widget-options)

## Use the field inside a Form

`PlacesAutocompleteFormField` supports normal Flutter validation and reset
behavior:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: PlacesAutocompleteFormField(
    apiKey: apiKey,
    validator: (selection) =>
        selection == null ? 'Choose a place.' : null,
  ),
);

formKey.currentState!.reset();
```

It also takes `onSaved`, `initialValue`, `autovalidateMode`, `forceErrorText`,
`errorBuilder`, and `restorationId`, as other form fields do.

### Start from a saved place

To show a place the user picked earlier, in an edit form for example, keep its
place ID, which
[Google lets you store](https://developers.google.com/maps/documentation/places/web-service/place-id),
and fetch the place again when the form opens:

```dart
final place = await client.fetchPlaceById(savedPlaceId);

PlacesAutocompleteFormField(
  client: client,
  initialValue: PlaceSelection.fromPlace(place),
);
```

The field shows the place's formatted address. `fetchPlaceById` asks for
`PlaceFieldPresets.address` by default: one Place Details Essentials request,
outside any autocomplete session. Outside a form, give the selection to the
controller instead:

```dart
final controller = PlacesAutocompleteController()
  ..restoreSelection(PlaceSelection.fromPlace(place));
```

## Fill an address form

One pick can fill the rest of an address form. Set your other fields from the place in
`onSelection`, and empty them in `onClearField`, which is called when the user clears the field or
types over the pick:

```dart
final street = TextEditingController();
final city = TextEditingController();
final region = TextEditingController();
final postalCode = TextEditingController();
final country = TextEditingController();

void fill(PlaceData? place) {
  street.text = place?.streetAddress ?? '';
  city.text = place?.city ?? '';
  region.text = place?.administrativeArea ?? '';
  postalCode.text = place?.postalCode ?? '';
  country.text = place?.country ?? '';
}

PlacesAutocompleteFormField(
  apiKey: apiKey,
  includedPrimaryTypes: PlaceTypePresets.address,
  onSelection: (selection) => fill(selection.place),
  onClearField: () => fill(null),
);
```

The default `selectionFields`, `PlaceFieldPresets.address`, returns every part these getters read,
so each pick costs one Place Details Essentials request. It works the same in dialog and
fullscreen field modes, where clearing inside the search clears the field too.
`FormState.reset()` does not call `onClearField`.

`PlaceTypePresets.address` limits the suggestions to precise addresses: a street address, a
building, or a unit in one. The other presets are `cities`, `regions`, `postalCode`, and
`establishment`. `cities` and `regions` must be used on their own; the others combine with each
other and with your own types, up to five:
`includedPrimaryTypes: [...PlaceTypePresets.address, ...PlaceTypePresets.postalCode]`.

## Search in a dialog or on a full screen

`PlacesAutocompleteOverlay.show()` opens the search and returns the pick, or
`null` if the user dismisses it:

```dart
final selection = await PlacesAutocompleteOverlay.show(
  context,
  apiKey: apiKey,
  mode: PlacesAutocompleteOverlayMode.fullscreen,
);
```

`mode` defaults to `dialog`. To open the search from a field the user taps
instead, give the field a `fieldMode`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  fieldMode: PlacesAutocompleteFieldMode.dialog,
  onSelection: (selection) => debugPrint(selection.displayText),
)
```

Every search option on the field — `decoration`, `origin`, `selectionFields`,
and the rest — reaches the dialog and fullscreen search too.

In both, the field stays in place and only the results scroll. The fullscreen
search puts the field in the top bar with a back button, as platform search
screens do, and opens as a regular page, so the system back gesture closes it.

## Change or translate the widget's text

Every piece of text the widgets show comes from `PlacesStrings`. Pass your own
to `strings:`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  strings: const PlacesStrings(
    searchHint: 'Rechercher un lieu',
    loadingText: 'Chargement des lieux…',
    noResultsText: 'Aucun lieu correspondant.',
    errorText: 'Impossible de charger les lieux.',
    retryText: 'Réessayer',
    poweredByGoogleLabel: 'Fourni par Google',
    overlayTitle: 'Rechercher des lieux',
    closeLabel: 'Fermer',
    clearLabel: 'Effacer la recherche',
    placeSuggestionLabel: 'Suggestion de lieu',
    querySuggestionLabel: 'Suggestion de recherche',
    distanceUnitMeters: 'm',
  ),
)
```

Any string you leave out keeps its English default. The package does not yet
pick a language for you, so an app in another language passes every string
itself; the [API reference](api_reference.md#display-strings) lists them all.
`languageCode:` is separate: it sets the language of Google's results, not of
the widget's own text.

The photo attribution's "Photo by" is not in `PlacesStrings` yet. Set it on the
widget instead: `PlacesPhotoAttribution(photo: photo, prefix: 'Photo de')`.

## Limit results to an area

`locationBias` prefers places in an area but can still return others.
`locationRestriction` returns only places inside it. Both take a circle or a
rectangle:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  locationBias: LocationBias.circle(
    center: const PlaceCoordinates(latitude: 51.5074, longitude: -0.1278),
    radiusMeters: 20000,
  ),
)
```

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  locationRestriction: LocationRestriction.rectangle(
    low: const PlaceCoordinates(latitude: 51.28, longitude: -0.51),
    high: const PlaceCoordinates(latitude: 51.69, longitude: 0.33),
  ),
)
```

`low` is the south-west corner and `high` the north-east one. Use one of the
two options, not both. A circle's radius can be at most 50,000 meters.

Some calls accept only one shape:

| Call | `locationBias` | `locationRestriction` |
| --- | --- | --- |
| Autocomplete (the widgets, `autocomplete()`) | circle or rectangle | circle or rectangle |
| Autocomplete through Maps JavaScript — the web default | circle or rectangle | rectangle only; a circle fails with a `validation` error |
| `searchText()` | circle or rectangle | rectangle only |
| `searchNearby()` | — | circle only, and required |

To limit results to whole countries rather than an area, use
`includedRegionCodes` instead.

## Get a place's time zone

There are two ways, and they return different things.

Add `PlaceField.timeZone` or `PlaceField.utcOffsetMinutes` to the details
request. They come back on the place, with no second API:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  selectionFields: {
    ...PlaceFieldPresets.address,
    PlaceField.timeZone,
    PlaceField.utcOffsetMinutes,
  },
  onSelection: (selection) {
    final place = selection.place!;
    debugPrint(place.timeZone?.id); // America/New_York
    debugPrint('${place.utcOffsetMinutes}'); // -240, the offset now
  },
)
```

Both are Pro fields, so the details request is no longer billed as Essentials.

Or set `fetchTimeZoneOnSelection: true`. After the details request, the widget
calls Google's Time Zone API and puts a `PlaceTimeZoneData` on the selection:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  fetchTimeZoneOnSelection: true,
  selectionTimeZoneAt: DateTime.utc(2026, 12, 25, 12),
  onSelection: (selection) {
    final zone = selection.timeZone!;
    debugPrint(zone.timeZoneId); // America/New_York
    debugPrint(zone.timeZoneName); // Eastern Standard Time
    debugPrint('${zone.rawOffset + zone.dstOffset}'); // -5:00:00.000000
  },
)
```

`rawOffset` is the standard offset and `dstOffset` the daylight-saving part, at
`selectionTimeZoneAt` (now, when unset). The Time Zone API is billed separately
and must be enabled for the key. This option always makes the details request,
even with `fetchPlaceDetailsOnSelection: false`, and adds `PlaceField.location`
to it, which is Essentials.

Without a widget, `client.fetchTimeZoneForPlace(place)` and
`client.fetchTimeZone(TimeZoneRequest(location: coordinates))` return the same
`PlaceTimeZoneData`.

## Customize the field and the suggestions

Four steps, lightest first. Stop at the first one that does what you need.

**1. Restyle the default rows with a theme.** The suggestion rows are
`ListTile`s, so the `listTileTheme` of a `Theme` around the field — or of your
app's `ThemeData` — changes their text, colours, and padding:

```dart
Theme(
  data: Theme.of(context).copyWith(
    listTileTheme: const ListTileThemeData(
      titleTextStyle: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      subtitleTextStyle: TextStyle(fontSize: 13),
    ),
  ),
  child: PlacesAutocompleteField(apiKey: apiKey),
)
```

The characters that match the typed text stay bold. Use a `Theme` rather than a
`ListTileTheme` widget: the dialog and fullscreen search get the `Theme`, but
Flutter does not carry a `ListTileTheme`'s text styles into them.

**2. Build each row.** `suggestionItemBuilder` replaces the whole row. It gets
the suggestion, whether the keyboard has highlighted it, and `onSelected`,
which selects it as a tap on a default row does:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  suggestionItemBuilder: (context, item) => switch (item.suggestion) {
    final PlaceSuggestion place => ListTile(
      tileColor: item.highlighted ? Theme.of(context).focusColor : null,
      leading: const Icon(Icons.place_outlined),
      title: Text(place.primaryText.text),
      subtitle: Text(place.secondaryText?.text ?? ''),
      onTap: item.onSelected,
    ),
    final QuerySuggestion query => ListTile(
      leading: const Icon(Icons.search),
      title: Text(query.displayText),
      onTap: item.onSelected,
    ),
  },
)
```

A `QuerySuggestion` only arrives with `includeQueryPredictions: true`. The
default rows carry a screen-reader label; give your rows one too, for example
with `Semantics`.

**3. Build the whole suggestion area.** `suggestionsViewBuilder` gets the
area's `status` — `loading`, `results`, `empty`, or `error` — the built rows as
`items`, the typed `error`, `onRetry`, Google's `attribution`, and
`defaultView`, the package's own view for the current state. Change only the
states you care about:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  suggestionsViewBuilder: (context, view) => switch (view.status) {
    PlacesSuggestionsStatus.error
        when view.error?.kind == PlacesErrorKind.network =>
      Card(
        child: ListTile(
          title: const Text('You are offline.'),
          trailing: TextButton(
            onPressed: view.onRetry,
            child: const Text('Try again'),
          ),
        ),
      ),
    _ => view.defaultView,
  },
)
```

The same builder caps the area's height, or adds dividers between rows:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  suggestionsViewBuilder: (context, view) => ConstrainedBox(
    constraints: const BoxConstraints(maxHeight: 240),
    child: view.status == PlacesSuggestionsStatus.results
        ? Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: view.items.length,
                    itemBuilder: (context, index) => view.items[index],
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1),
                  ),
                ),
                if (view.attribution case final attribution?)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: attribution,
                  ),
              ],
            ),
          )
        : view.defaultView,
  ),
)
```

Put `view.items` in your list rather than building rows yourself, so arrow
keys keep the highlighted row in view. Inline, the area floats over the page
with the field's width and whatever height is left above the keyboard, so make
it scroll. Keep `view.attribution` beside the results: Google requires
attribution beside its data when no Google map is shown.

**4. Build the field.** `fieldBuilder` replaces the text field. It must use the
`controller` and `focusNode` it is given and call `onChanged` when the user
types — that call starts the search. `onTap` opens the dialog or fullscreen
search in those field modes, `onClear` clears everything, and
`selectionLoading` is `true` while the picked place's details load. The
default field draws a progress bar meanwhile; a custom one shows its own.
Honour `readOnly` and `enabled` where your field can. `decoration` is not used;
in a form, the validation message arrives as `errorText`, and the form field's
`errorBuilder` is not used.

Every builder reaches the dialog and fullscreen search too.

### A Cupertino-style search

The three builders together give a search that uses no Material widget. This
uses `package:cupertino_ui`, which your app adds itself:

```dart
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

PlacesAutocompleteField(
  apiKey: apiKey,
  fieldBuilder: (context, field) => CupertinoSearchTextField(
    controller: field.controller,
    focusNode: field.focusNode,
    placeholder: field.strings.searchHint,
    onChanged: field.onChanged,
    onTap: field.onTap,
    onSuffixTap: field.onClear ?? () {},
    enabled: field.enabled,
    autofocus: field.autofocus,
  ),
  suggestionItemBuilder: (context, item) {
    final background = item.highlighted
        ? CupertinoColors.systemFill.resolveFrom(context)
        : null;
    return switch (item.suggestion) {
      final PlaceSuggestion place => CupertinoListTile(
        onTap: item.onSelected,
        backgroundColor: background,
        title: Text(place.primaryText.text),
        subtitle: place.secondaryText == null
            ? null
            : Text(place.secondaryText!.text),
      ),
      final QuerySuggestion query => CupertinoListTile(
        onTap: item.onSelected,
        backgroundColor: background,
        leading: const Icon(CupertinoIcons.search),
        title: Text(query.displayText),
      ),
    };
  },
  suggestionsViewBuilder: (context, view) => SingleChildScrollView(
    child: CupertinoListSection.insetGrouped(
      footer: view.status == PlacesSuggestionsStatus.results
          ? view.attribution
          : null,
      children: switch (view.status) {
        PlacesSuggestionsStatus.results => view.items,
        PlacesSuggestionsStatus.loading => <Widget>[
          CupertinoListTile(
            leading: const CupertinoActivityIndicator(),
            title: Text(view.strings.loadingText),
          ),
        ],
        PlacesSuggestionsStatus.empty => <Widget>[
          CupertinoListTile(title: Text(view.strings.noResultsText)),
        ],
        PlacesSuggestionsStatus.error => <Widget>[
          CupertinoListTile(
            title: Text(view.strings.errorText),
            trailing: CupertinoButton(
              onPressed: view.onRetry,
              child: Text(view.strings.retryText),
            ),
          ),
        ],
      },
    ),
  ),
)
```

`onSuffixTap: field.onClear ?? () {}` matters. Without a callback,
`CupertinoSearchTextField` clears the text itself and reports it as an edit,
which the widget ignores in the dialog and fullscreen field modes, so the
selection would survive the clear. `CupertinoSearchTextField` has no read-only
option; typing into it while a picked place's details load simply abandons that
pick and searches again.
The same field works inside a `CupertinoApp`; the package then prints a one-time
note in debug builds and needs nothing else. The dialog and fullscreen search
keep their own Material top bar and dialog frame.

### Your own field in an app on `package:flutter/material.dart`

An app that has not moved to `material_ui` can return its own `TextField` and
keep its own theme. Wrap it in a `Material`, which the dialog and fullscreen
search need:

```dart
import 'package:flutter/material.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';

PlacesAutocompleteField(
  apiKey: apiKey,
  fieldBuilder: (context, field) => Material(
    type: MaterialType.transparency,
    child: TextField(
      controller: field.controller,
      focusNode: field.focusNode,
      onChanged: field.onChanged,
      onTap: field.onTap,
      readOnly: field.readOnly,
      enabled: field.enabled,
      autofocus: field.autofocus,
      decoration: InputDecoration(
        hintText: field.strings.searchHint,
        errorText: field.errorText,
      ),
    ),
  ),
)
```

Here `Material`, `TextField`, and `InputDecoration` are the app's own,
from `package:flutter/material.dart`.

## Search without a widget

`PlacesClient` makes the same calls the widgets make, plus Text Search, Nearby
Search, Place Photos, and Time Zone. Create one client, share it, and close it
when you are done:

```dart
final client = PlacesClient(apiKey: apiKey);

final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

for (final place in results) {
  debugPrint(place.displayName?.text);
}

await client.close();
```

Text Search and Nearby Search return `PlaceFieldPresets.minimal` by default —
a name, an address, and coordinates — and Place Details returns
`PlaceFieldPresets.address`. Pass `fields:` to ask for more.

Use `searchTextPage()` only when pagination metadata is needed:

```dart
final page = await client.searchTextPage(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

if (page.nextPageToken case final token?) {
  final nextPage = await client.searchTextPage(
    TextSearchRequest(
      textQuery: 'coffee near me',
      pageSize: 10,
      pageToken: token,
    ),
  );
  debugPrint('${nextPage.results.length} more places');
}
```

When requesting a later page, keep every other value from the first request
unchanged.

Nearby Search finds places of a type around a point, with no text query. Its
area is required and must be a circle:

```dart
final cafes = await client.searchNearby(
  NearbySearchRequest(
    locationRestriction: LocationRestriction.circle(
      center: const PlaceCoordinates(latitude: 40.7580, longitude: -73.9855),
      radiusMeters: 500,
    ),
    includedTypes: const ['cafe'],
  ),
);
```

## Build your own autocomplete UI

`PlacesAutocompleteController` runs the search for your own UI: you draw the field and the
suggestions, and it sends the requests, waits between keystrokes, and keeps every search and the
pick in one billing session.

```dart
class PlaceSearch extends StatefulWidget {
  const PlaceSearch({super.key});

  @override
  State<PlaceSearch> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends State<PlaceSearch> {
  final controller = PlacesAutocompleteController(apiKey: 'YOUR_API_KEY');

  @override
  void dispose() {
    controller.dispose(); // Ends the session and closes the client.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller.textController,
          focusNode: controller.focusNode,
          onChanged: (_) => controller.search(),
        ),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => switch (controller.status) {
            PlacesSuggestionsStatus.loading => const LinearProgressIndicator(),
            PlacesSuggestionsStatus.error => TextButton(
              onPressed: controller.retry,
              child: const Text('Try again'),
            ),
            _ => Column(
              children: [
                for (final suggestion in controller.suggestions)
                  ListTile(
                    title: Text(suggestion.displayText),
                    onTap: () async {
                      final selection = await controller.select(suggestion);
                      debugPrint('${selection?.place?.location}');
                    },
                  ),
              ],
            ),
          },
        ),
      ],
    );
  }
}
```

- `search()` follows the widget's rules: it waits `debounceDuration` (300 ms), sends nothing for
  text shorter than `minInputLength`, and replaces an earlier search.
- `select()` loads the place's coordinates and address — `PlaceFieldPresets.address`, as the
  widgets do — and ends the session with that request. It completes with the error if a request
  fails.
- When the user leaves your search without picking, call `controller.resetSession()` to end the
  session; `dispose()` does it too.
- Search and selection settings go in `options`, under the widgets' names:
  `PlacesAutocompleteController(apiKey: key, options: PlacesAutocompleteOptions(regionCode: 'us'))`.
- Google's policies require its attribution where you show its suggestions without a Google map;
  see [Places policies](https://developers.google.com/maps/documentation/places/web-service/policies).

Pass `client:` instead of `apiKey:` to share a client; the controller never closes one it was
given. Pass your own `textController` or `focusNode` to share them with the rest of your UI.

### Search again with a picked query suggestion

With `includeQueryPredictions: true` the suggestions include phrases such as "coffee near me".
Picking one fills the field and ends the session. To search for it straight away, so the user can
pick a place from the results, set `searchOnQuerySelection`:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  includeQueryPredictions: true,
  searchOnQuerySelection: true,
)
```

It works in every field mode, on `PlacesAutocompleteFormField`, and on
`PlacesAutocompleteOverlay.show()`. The search runs in a new billing session.

For something else — searching for different text, say — pass a controller and do it in
`onQuerySelection`, which is called first:

```dart
final controller = PlacesAutocompleteController();

PlacesAutocompleteField(
  apiKey: apiKey,
  controller: controller,
  includeQueryPredictions: true,
  onQuerySelection: (query) {
    controller.textController.text = '${query.displayText} open now';
    controller.search();
  },
)
```

A field in dialog or fullscreen mode opens its search with a controller of its own, so for those
pass the controller to `PlacesAutocompleteOverlay.show()` instead.

### A controller passed to a widget

While a widget uses a controller, the widget's own search parameters and client apply, not the
controller's `options` and client, and the widget's `debounceDuration`, when set, replaces the
controller's. The controller's own apply again once no widget uses it. One widget uses a
controller at a time.

### Without the controller

`PlacesClient` takes the session token directly. Reuse one token for the whole search, pass it to
Place Details, and end an abandoned session explicitly:

```dart
final sessionToken = AutocompleteSessionToken.generate();

final suggestions = await client.autocomplete(
  AutocompleteRequest(
    input: 'coffee',
    sessionToken: sessionToken,
  ),
);

if (suggestions.isEmpty) {
  await client.endAutocompleteSession(sessionToken);
} else {
  final place = await client.fetchPlace(
    PlaceDetailsRequest(
      placeId: suggestions.first.placeId,
      sessionToken: sessionToken,
    ),
  );
  debugPrint(place.formattedAddress);
}
```

Use `autocompleteSuggestions()` with `includeQueryPredictions: true` when the
application also accepts suggested search phrases instead of only places.

## Show the distance from the user's location

Set `origin` and Google returns a distance for every suggestion, which the field
renders beside it:

```dart
PlacesAutocompleteField(
  apiKey: apiKey,
  origin: const PlaceCoordinates(latitude: 40.7580, longitude: -73.9855),
)
```

Two things to know before you use it:

- Distances are **straight-line**, not driving or walking distance. They will
  not match what a maps app shows for the same pair.
- `origin` only computes the number. It does not change which places are
  returned — use `locationBias` or `locationRestriction` for that.

Without `origin`, no distance is requested and none is rendered. That is the
default.

### Using the device's location as the origin

**This package never requests location permission, and does not depend on any
location library.** Your app fetches the coordinates and passes them in. Any
package works; the example below uses
[`geolocator`](https://pub.dev/packages/geolocator).

Add the platform configuration first, or the request fails at runtime:

`android/app/src/main/AndroidManifest.xml`, inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

`ios/Runner/Info.plist`, inside the top-level `<dict>`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Used to show how far each place is from you.</string>
```

On web the browser prompts on its own, but the page must be served over HTTPS
(or `localhost`). macOS needs a location entitlement in both
`macos/Runner/DebugProfile.entitlements` and `Release.entitlements`. Desktop
support otherwise depends on the location package you choose, not on this one.

Then resolve the coordinates and hand them to the field:

```dart
class _SearchPageState extends State<SearchPage> {
  PlaceCoordinates? _origin;

  @override
  void initState() {
    super.initState();
    _loadOrigin();
  }

  Future<void> _loadOrigin() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    final position = await Geolocator.getCurrentPosition();
    if (!mounted) {
      return;
    }
    setState(() {
      _origin = PlaceCoordinates(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return PlacesAutocompleteField(client: widget.client, origin: _origin);
  }
}
```

Every early return leaves `_origin` as `null`, so search keeps working and
simply shows no distances. Denying permission degrades the feature rather than
breaking the field.

A first GPS fix can take several seconds. Resolving it in `initState` as above
means the field is usable immediately and distances appear once the fix lands —
do not block the search on it.

## Display photo attribution

Photos are not in the default fields: add `PlaceField.photos` to
`selectionFields` or `fields:`, or `place.photos` comes back empty. When a
returned photo includes authors, display Google's supplied attribution beside
the image:

```dart
PlacesPhotoAttribution(photo: photo)
```

`PlacePhoto.authors` is available when a custom attribution layout is needed.
Each `client.fetchPhotoMedia()` call is billed separately.

## Cancel work that is no longer needed

Every client operation accepts an optional cancellation token:

```dart
final cancellation = PlacesCancellationToken();

final request = client.searchText(
  const TextSearchRequest(textQuery: 'coffee'),
  cancellationToken: cancellation,
);

cancellation.cancel();
await request;
```

HTTP transports abort the request. Maps JavaScript safely ignores a late
completion and reports a typed cancellation error. The widgets cancel their own
work when they are disposed.

## Secure proxy and platform identity

Use a keyless authenticated proxy client when the application should not carry
a Google web-service key:

```dart
final client = PlacesClient.proxy(
  placesEndpoint: Uri.parse('https://api.example.com/maps/places/v1'),
  timeZoneEndpoint: Uri.parse('https://api.example.com/maps/timezone'),
  authentication: (_) async => <String, String>{
    'Authorization': 'Bearer ${await session.currentAccessToken()}',
  },
);
```

The proxy must authenticate clients, allowlist operations, enforce quotas, and
add its restricted Google credential server-side. The package never forwards a
Google key to configured proxy endpoints.

For a key restricted to your Android or iOS app, send the app's identity. A
client made from a widget's `apiKey:` cannot, so build one and pass it as
`client:`:

```dart
final client = PlacesClient(
  apiKey: apiKey,
  options: const PlacesClientOptions(
    applicationIdentity: PlacesApplicationIdentity.android(
      'com.example.app',
      'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
    ),
  ),
);
```

`PlacesApplicationIdentity.ios(bundleIdentifier)` is the iOS equivalent, and
`PlacesProxyConfiguration` can combine Maps JavaScript with a proxy fallback on
web. See [Security and transport configuration](security_and_transports.md) for
the setup guide, transport matrix, CSP options, and direct-fallback risks.

## Typed errors and HTTP ownership

All package-generated failures are `PlacesException` values:

```dart
try {
  await client.searchText(
    const TextSearchRequest(textQuery: 'coffee'),
  );
} on PlacesException catch (error) {
  debugPrint('${error.kind.name}: ${error.message}');
  if (error.retryable) {
    // Offer a retry action.
  }
}
```

The widgets pass the same errors to `onError`.

`kind` is the value to `switch` on:

| `PlacesErrorKind` | Meaning |
| --- | --- |
| `validation` | The request broke a documented limit and was never sent. |
| `configuration` | The client or transport is set up wrongly. |
| `network` | No response arrived — offline, DNS, or a dropped connection. |
| `timeout` | The request took longer than `PlacesClientOptions.requestTimeout`. |
| `cancellation` | The caller or the widget cancelled the work. |
| `http` | A non-success HTTP response with no Google error in it. |
| `googleApi` | Google returned an error, such as `PERMISSION_DENIED`; `code` holds its status. |
| `proxy` | Your proxy returned an invalid or proxy-specific response. |
| `javascript` | Maps JavaScript failed to load or to run, on web. |
| `unknown` | Anything the package could not classify. |

An injected `http.Client` remains caller-owned by default. Transfer ownership
only when `PlacesClient.close()` should also close it:

```dart
final client = PlacesClient(
  apiKey: apiKey,
  httpClient: injectedClient,
  options: const PlacesClientOptions(
    httpClientOwnership: PlacesHttpClientOwnership.placesClient,
  ),
);
```

HTTP client injection is unsupported on web.

## Common widget options

The same names work on `PlacesAutocompleteField`, `PlacesAutocompleteFormField`,
and `PlacesAutocompleteOverlay.show()`, except the two marked inline only. The
[API reference](api_reference.md#widget-defaults) lists every option, including
`TextField`'s own options — every one a one-line search field can use, from `keyboardType`
and `inputFormatters` to the cursor and spell-check options — which are passed to the default
field.

| Option | Default | Use when |
| --- | --- | --- |
| `apiKey` / `client` | one required | The widget owns a client, or you share yours. |
| `fieldMode` | `inline` | You want inline, dialog, or fullscreen UI. |
| `languageCode` | `null` | You want localized Google results. |
| `regionCode` | `null` | You want region-aware ranking or formatting. |
| `includedRegionCodes` | empty | You only want results in some countries. |
| `includedPrimaryTypes` | empty | You want types such as `restaurant` or `PlaceTypePresets.cities`. |
| `locationBias` | `null` | You prefer results near an area. |
| `locationRestriction` | `null` | You only want results inside an area. |
| `origin` | `null` | You want a distance beside each suggestion. |
| `fetchPlaceDetailsOnSelection` | `true` | Set `false` when only the place ID is needed. |
| `selectionFields` | `address` | You need more than coordinates and an address. |
| `fetchTimeZoneOnSelection` | `false` | The selection needs Time Zone API data. |
| `includeQueryPredictions` | `false` | You also accept suggested search phrases. |
| `maxSuggestions` | `5` | You want fewer than Google's five suggestions. |
| `minInputLength` | `1` | You want fewer billed requests: no search until this many characters. |
| `debounceDuration` | 300 ms | You want fewer billed requests: a longer pause before each search. |
| `keyboardType` | `streetAddress` | You want another keyboard. The default changes it on Android and Linux only. |
| `includeFutureOpeningBusinesses` | `false` | You also want places that have not opened yet. |
| `unfocusOnSelection` | `true` | Inline only. Set `false` to keep focus in the field after a pick. |
| `suggestionsViewOpenDirection` | `mostSpace` | Inline only. The suggestions should always open `down` or `up`. |
| `showPoweredByGoogle` | `true` | The package should render Google attribution. |

`locationBias` and `locationRestriction` cannot be used together; see
[Limit results to an area](#limit-results-to-an-area). `strings` changes the
widget's own text; see
[Change or translate the widget's text](#change-or-translate-the-widgets-text).
`fieldMode` belongs to the field widgets; `show()` takes `mode` instead.
