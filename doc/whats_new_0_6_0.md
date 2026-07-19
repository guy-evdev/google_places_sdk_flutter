# What's new in 0.6.0

Version `0.6.0` adds pagination, cancellation, richer Place data, safer
transports, and more complete Flutter form behavior.

There are no public API removals or required source migrations in this release.
Most applications can update without changing their code. Deprecated APIs still
work, but the replacements below are recommended for new code.

## Deprecations

### `maxResultCount` → `pageSize`

**Deprecated in 0.6.0; planned removal in 1.0.0.** Replace Text Search
`maxResultCount` with `pageSize`.

Before:

```dart
final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    maxResultCount: 10,
  ),
);
```

Now:

```dart
final results = await client.searchText(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);
```

`searchText()` still returns a simple `List<PlaceData>`, so no other change is
needed unless the application wants pagination metadata.

### `proxyBaseUrl` → typed proxy configuration

**Deprecated in 0.6.0; planned removal in 1.0.0.** Replace the string
`proxyBaseUrl` option with `PlacesClient.proxy()` or
`PlacesProxyConfiguration`.

```dart
final client = PlacesClient.proxy(
  placesEndpoint: Uri.parse('https://api.example.com/maps/places/v1'),
  timeZoneEndpoint: Uri.parse('https://api.example.com/maps/timezone'),
  authentication: (_) async => <String, String>{
    'Authorization': 'Bearer ${await session.currentAccessToken()}',
  },
);
```

The typed API validates endpoints and keeps Google credentials on the proxy
server.

### Direct browser REST fallback

**Deprecated in 0.6.0.** `PlacesWebFallbackPolicy.direct` remains the `0.6.x`
default for compatibility, but is scheduled to stop being the default in
`1.0.0`. Use an authenticated proxy for REST-only web operations such as Place
Photos, Time Zone, and paged Text Search.

See the [security and transport guide](security_and_transports.md) when the
application is ready to configure production web or proxy behavior.

## Compatibility notices

These are behavior changes rather than public API breaks.

### Proxy requests no longer receive a Google key

Starting in `0.6.0`, configured proxy requests never receive `key` or
`X-Goog-Api-Key` from the application. If an existing proxy expected the client
to send that key, move it to the proxy server before updating. The proxy should
authenticate the application and add its own restricted Google credential only
on the server-to-Google request.

### Injected HTTP clients remain caller-owned

An injected `http.Client` is no longer closed by `PlacesClient.close()` unless
ownership is explicitly transferred. Most applications do not inject a client
and are unaffected.

To keep the previous ownership behavior:

```dart
final client = PlacesClient(
  apiKey: apiKey,
  httpClient: injectedClient,
  options: const PlacesClientOptions(
    httpClientOwnership: PlacesHttpClientOwnership.placesClient,
  ),
);
```

Passing an HTTP client on web now produces a clear configuration error instead
of being silently ignored.

### Requests now have a default deadline

Requests have a 15-second default timeout, and invalid request values fail
locally before network work starts. Applications with a legitimately slower
proxy can set a longer `PlacesClientOptions.requestTimeout`.

## New features

### Paged Text Search

Use `searchTextPage()` when the application needs `nextPageToken` or
`searchUri`:

```dart
final firstPage = await client.searchTextPage(
  const TextSearchRequest(
    textQuery: 'coffee near me',
    pageSize: 10,
  ),
);

if (firstPage.nextPageToken case final token?) {
  final secondPage = await client.searchTextPage(
    TextSearchRequest(
      textQuery: 'coffee near me',
      pageSize: 10,
      pageToken: token,
    ),
  );
  debugPrint('${secondPage.results.length} more places');
}
```

Keep the original filters unchanged when requesting another page. On web,
paged Text Search uses the configured HTTP or proxy route because Maps
JavaScript does not expose REST pagination metadata.

### Caller cancellation

Every client operation accepts an optional `PlacesCancellationToken`:

```dart
final cancellation = PlacesCancellationToken();

final request = client.searchText(
  const TextSearchRequest(textQuery: 'coffee'),
  cancellationToken: cancellation,
);

cancellation.cancel();
await request;
```

HTTP requests are aborted. Maps JavaScript results are safely ignored if they
finish after cancellation.

### Flutter Form support

`PlacesAutocompleteFormField` now follows Flutter's normal initial value,
validation, controller, and reset behavior:

```dart
final formKey = GlobalKey<FormState>();

Form(
  key: formKey,
  child: PlacesAutocompleteFormField(
    client: client,
    validator: (selection) =>
        selection == null ? 'Choose a place.' : null,
  ),
);

formKey.currentState!.reset();
```

### Richer Place data and photo attribution

The package now covers the current stable Place field mask with typed models
for common data such as opening dates, time zones, Google Maps links, prices,
attributions, and transit stations. Large or evolving Google payloads remain
available as deeply immutable JSON.

Photo authors are available through `PlacePhoto.authors`. Display the supplied
attribution beside a photo with:

```dart
PlacesPhotoAttribution(photo: photo)
```

### Safer errors and validation

`PlacesException` now provides typed `kind`, `operation`, `code`, `statusCode`,
and `retryable` values. Validation, timeout, HTTP, Google API, proxy, and Maps
JavaScript failures use the same error type and omit credentials from
diagnostics.

## Enhancements and fixes

- Autocomplete billing sessions are preserved through selection on web.
- Widgets cancel stale searches and selection work when replaced or disposed.
- Form reset works with both package-owned and external controllers.
- Switching between regular and Form fields with one external controller no
  longer dispatches controller notifications during the Flutter build phase.
- The example app now keeps options in a configuration sheet, summarizes the
  active choices, and accepts user-entered single-page or paged Text Searches.
- Retry, close, and Google attribution semantics use the active package
  strings.
- Text Search adds price, pure-service-area, future-opening, and pagination
  options.
- Autocomplete and Nearby Search add future-opening-business filters.
- HTTP ownership, cancellation, and timeout behavior is explicit and tested.

## Advanced transport and client options

Production applications that need a proxy, direct mobile REST restrictions,
CSP nonces, Maps JavaScript version channels, custom timeouts, or HTTP client
ownership can use `PlacesClientOptions`, `PlacesProxyConfiguration`, and
`PlacesApplicationIdentity`.

Start with the [security and transport guide](security_and_transports.md), then
use the [API reference](api_reference.md) for the complete option and field
tables.
