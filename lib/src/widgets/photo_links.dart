import 'package:flutter/foundation.dart';

import '../models/place_models.dart';
import 'photo_links_io.dart'
    if (dart.library.js_interop) 'photo_links_web.dart'
    as platform;

bool _noticeShown = false;

/// Lets tests observe the once-per-run debug notice again.
@visibleForTesting
void debugResetPhotoLinkNotice() => _noticeShown = false;

/// [raw] as a link that is safe to open, or `null`.
///
/// Only `https` and `http` links are opened: the link comes from a response,
/// possibly through a proxy, and must never become a `javascript:` URL or
/// carry credentials.
/// Google returns author profile links without a scheme
/// (`//maps.google.com/maps/contrib/…`), so those get `https`.
Uri? safePhotoLink(String? raw) {
  var uri = raw == null ? null : Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return null;
  }
  if (uri.scheme.isEmpty) {
    uri = uri.replace(scheme: 'https');
  }
  return uri.isScheme('https') || uri.isScheme('http') ? uri : null;
}

/// What opens a photo's links: the app's [onOpenLink], else a browser tab on
/// web, else `null` — in which case a debug notice is printed once per run if
/// [photo] has a link Google requires the user to be able to open.
ValueChanged<Uri>? photoLinkOpener(
  ValueChanged<Uri>? onOpenLink,
  PlacePhoto photo,
) {
  final opener = onOpenLink ?? platform.platformOpenLink;
  assert(opener != null || _debugNoticeOnce(photo));
  return opener;
}

/// Whether a photo attribution has anything to draw with [opener].
bool photoHasAttribution(PlacePhoto photo, ValueChanged<Uri>? opener) =>
    photo.authors.any((author) => author.displayName.trim().isNotEmpty) ||
    (opener != null && safePhotoLink(photo.googleMapsUri) != null);

bool _debugNoticeOnce(PlacePhoto photo) {
  if (!_noticeShown && safePhotoLink(photo.googleMapsUri) != null) {
    _noticeShown = true;
    debugPrint(
      'google_places_sdk_flutter: Google requires users to be able to open a '
      'place photo on Google Maps, but this PlacePhotoView or '
      'PlacesPhotoAttribution has no onOpenLink, and on this platform the '
      'package cannot open a link itself, so the link is not shown. Pass '
      'onOpenLink, for example `onOpenLink: (uri) => launchUrl(uri)` with '
      'url_launcher in your app.',
    );
  }
  return true;
}
