# Security and transport configuration

Start with the transport that matches the application. Most widget usage does
not need custom transport settings.

| Application need | Recommended setup |
| --- | --- |
| Autocomplete and Place Details on web | Website-restricted Maps JavaScript key |
| REST-only operations on web | Maps JavaScript plus an authenticated proxy |
| An application that should carry no Google web-service key | `PlacesClient.proxy()` |
| Direct Android or iOS REST when a proxy is not practical | Separate restricted mobile key and application identity |

Google Maps Platform web-service keys are server credentials. Do not place an
unrestricted Places API or Time Zone API key in a browser bundle or untrusted
client. Google recommends an authenticated proxy for client-side web-service
calls when a client SDK cannot perform the operation.

Official guidance:

- [Google Maps Platform security guidance](https://developers.google.com/maps/api-security-best-practices)
- [Maps JavaScript loading parameters](https://developers.google.com/maps/documentation/javascript/load-maps-js-api)
- [Maps JavaScript version channels](https://developers.google.com/maps/documentation/javascript/versions)

## Keyless proxy client

Use `PlacesClient.proxy()` when every supported operation should go through an
authenticated server:

```dart
final client = PlacesClient.proxy(
  placesEndpoint: Uri.parse('https://api.example.com/maps/places/v1'),
  timeZoneEndpoint: Uri.parse('https://api.example.com/maps/timezone'),
  authentication: (_) async => <String, String>{
    'Authorization': 'Bearer ${await session.currentAccessToken()}',
  },
);
```

The application sends its own short-lived authentication to the proxy. The
proxy verifies that authentication and adds the restricted Google credential
only when it calls Google.

The package never adds `key` or `X-Goog-Api-Key` to a proxy request. Endpoints
must use HTTPS, except for loopback development, and cannot contain credentials,
query parameters, or fragments.

### Credentials are never placed in a URL

Every Places operation authenticates with the `X-Goog-Api-Key` header. No API
key is ever added to a request path or query string, and a regression test
asserts this across every operation.

The single exception is the Google Time Zone API, which offers no header
authentication and requires `key` as a query parameter. Applications that treat
URLs as sensitive should route Time Zone through a proxy `timeZoneEndpoint`,
which removes the key from the client entirely.

> **Fixed in 0.6.1.** Versions `0.5.0`–`0.6.0` also appended `key` to the photo
> media URL, where proxy logs, CDN logs, and browser history could record it. If
> an application called `fetchPhotoMedia` on those versions, rotate that API key.

### Proxy responsibilities

The proxy should:

- Authenticate and authorize every request.
- Allowlist operations, methods, headers, field masks, and upstream paths.
- Apply per-user or per-application rate limits and quotas.
- Add a server-held, API-restricted Google credential only upstream.
- Restrict that credential to the proxy's server IPs where practical.
- Return only fields needed by the application.
- Use narrow CORS origins.
- Avoid logging credentials, tokens, queries, coordinates, or response bodies.

The package authentication callback cannot override Google credential headers,
the host, field masks, or package-managed content headers. Package diagnostics
omit endpoints, authentication headers, CSP nonces, session tokens, and response
bodies.

## Web with proxy fallback

For a normal web autocomplete experience, use a website-restricted Maps
JavaScript key and add a proxy only for REST-only operations such as Place
Photos, Time Zone, and paged Text Search:

```dart
final client = PlacesClient(
  apiKey: const String.fromEnvironment('MAPS_JAVASCRIPT_API_KEY'),
  proxyConfiguration: PlacesProxyConfiguration(
    placesEndpoint: Uri.parse('https://api.example.com/maps/places/v1'),
    timeZoneEndpoint: Uri.parse('https://api.example.com/maps/timezone'),
    authentication: (_) async => <String, String>{
      'Authorization': 'Bearer ${await session.currentAccessToken()}',
    },
  ),
  options: const PlacesClientOptions(
    web: PlacesWebOptions(
      fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly,
    ),
  ),
);
```

`proxyOnly` allows Maps JavaScript operations and requires the configured proxy
for HTTP work. `disabled` turns off direct and proxy HTTP operations.

Direct browser REST fallback is deprecated because a browser cannot keep a
web-service key secret. It remains the `0.6.x` compatibility default and is
scheduled to stop being the default in `1.0.0`.

## Direct Android and iOS REST fallback

When a proxy is not practical, use a separate API-restricted key for each
platform and add Google's application identity headers.

The widget still receives one client. Create that client once for the platform
the application is currently running on:

```dart
import 'package:flutter/foundation.dart';

PlacesClient createDirectMobileClient() {
  if (kIsWeb) {
    throw UnsupportedError('Use Maps JavaScript or a proxy on web');
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return PlacesClient(
        apiKey: const String.fromEnvironment('ANDROID_PLACES_API_KEY'),
        options: const PlacesClientOptions(
          applicationIdentity: PlacesApplicationIdentity.android(
            'com.example.app',
            'BB:0D:AC:74:D3:21:E1:43:67:71:9B:62:91:AF:A1:66:6E:44:5D:75',
          ),
        ),
      );
    case TargetPlatform.iOS:
      return PlacesClient(
        apiKey: const String.fromEnvironment('IOS_PLACES_API_KEY'),
        options: const PlacesClientOptions(
          applicationIdentity: PlacesApplicationIdentity.ios(
            'com.example.app',
          ),
        ),
      );
    default:
      throw UnsupportedError('Direct mobile client requires Android or iOS');
  }
}

final client = createDirectMobileClient();

PlacesAutocompleteField(
  client: client,
  onSelection: (selection) {
    debugPrint(selection.displayText);
  },
);
```

Pass only the matching key define when building each platform, for example
`--dart-define=ANDROID_PLACES_API_KEY=...` for Android.

`PlacesClient` already chooses the correct web or non-web transport backend.
The small factory above only supplies the credential and identity belonging to
the current application platform. The package cannot infer an application's
API keys, Android signing certificate, or iOS bundle identifier.

Keeping this selection at client creation also keeps security configuration out
of the widget and avoids passing or retaining unused platform credentials in
the UI layer.

Configure matching application and API restrictions in Google Cloud. Verify
that deliberately incorrect identities are rejected by every endpoint the
application calls. Prefer a proxy if an endpoint does not enforce the expected
mobile restriction.

Application identity is rejected on web and is never sent to a configured
proxy.

## Photos and Time Zone

Place Photos and Time Zone are HTTP operations on every platform. Prefer the
authenticated proxy path when an untrusted client would otherwise carry a
web-service key.

When displaying a photo, render every returned author attribution. The simplest
Flutter implementation is:

```dart
PlacesPhotoAttribution(photo: photo)
```

`PlacePhoto.authors` provides the typed immutable values for a custom layout.

## Advanced web settings

Set `PlacesWebOptions.cspNonce` to the nonce from the current HTML response when
the package injects Maps JavaScript. The nonce is copied to the script element.

Choose the `weekly` Maps JavaScript channel for Google's current release or
`quarterly` for a more predictable update cadence. Configure an initialization
timeout when the application needs a value other than the package default.

```dart
const options = PlacesClientOptions(
  web: PlacesWebOptions(
    versionChannel: PlacesWebVersionChannel.quarterly,
    initializationTimeout: Duration(seconds: 10),
    fallbackPolicy: PlacesWebFallbackPolicy.proxyOnly,
  ),
);
```

## Transport matrix

| Operation | IO direct | Web JavaScript | Direct web HTTP | Keyless proxy |
| --- | --- | --- | --- | --- |
| Autocomplete | Places REST | Primary | Available | Available |
| Place Details | Places REST | Primary | Field fallback | Available |
| Text Search list | Places REST | Primary | Fallback | Available |
| Paged Text Search | Places REST | Not exposed | Required without proxy | Available |
| Nearby Search | Places REST | Primary | Fallback | Available |
| Place Photo media | Places REST | Not exposed | Required without proxy | Available |
| Time Zone | Time Zone REST | Not exposed | Required without proxy | With `timeZoneEndpoint` |

## Version 0.6 compatibility notices

- **0.6.1:** photo media no longer sends the API key as a URL query parameter.
  Rotate any key used with `fetchPhotoMedia` on `0.5.0`–`0.6.0`.
- String `PlacesClient.proxyBaseUrl` is deprecated. Use
  `PlacesProxyConfiguration` or `PlacesClient.proxy()`.
- Proxy requests no longer receive a Google API key from the application. An
  existing proxy that expected `key` or `X-Goog-Api-Key` must add its own
  server-side credential.
- Direct browser REST fallback is deprecated but remains the `0.6.x` default.

See [What's new in 0.6.0](whats_new_0_6_0.md) for replacement examples and the
complete release summary, and [What's new in 0.6.1](whats_new_0_6_1.md) for the
photo media credential fix.
