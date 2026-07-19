## 0.6.0 - 2026-07-20

- **Deprecated:** Text Search `maxResultCount` (use `pageSize`), string
  `proxyBaseUrl` (use typed proxy configuration), and direct browser REST
  fallback. Planned removal or default change: `1.0.0`.
- **New:** Text Search pagination, cancellation, richer Place data, photo
  attribution, typed errors, validation, and secure transport options.
- **Fixed:** autocomplete billing sessions, stale async work, Form behavior,
  response handling, and diagnostic redaction.
- **Compatibility:** proxy requests no longer receive Google keys; injected
  HTTP clients remain caller-owned unless ownership is transferred.

See [What's new in 0.6.0](doc/whats_new_0_6_0.md) for examples, behavior notes,
and complete details.

## 0.5.0 - 2026-06-03

- Added mixed autocomplete suggestions with opt-in query prediction support.
- Added Place Photos (New) media lookup through `fetchPhotoMedia`.
- Added newer Places API field masks for address descriptors, EV charging,
  fuel options, generative summaries, service-area businesses, and moved places.
- Improved autocomplete widget clear-button behavior, selection loading
  feedback, keyboard navigation, semantic labels, and text match highlighting.
- Enabled stricter analyzer settings and expanded Flutter 3.44 CI coverage.
- Compacted the README and added a dedicated API reference document.

## 0.4.2 - 2026-04-17

- Updated Dart docs, README media, and package screenshots.

## 0.4.1 - 2026-04-16

- Updated README preview images.

## 0.4.0 - 2026-04-16

Initial public release on pub.dev.

- Added a cross-platform Google Places API (New) client for Flutter.
- Added inline, dialog, and fullscreen autocomplete widgets.
- Added optional place-details and time-zone fetching on selection.
- Added typed address support with structured models and convenience getters.
- Added Android, iOS, web, macOS, Windows, and Linux example support.
