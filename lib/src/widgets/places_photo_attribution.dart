import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import 'photo_links.dart';
import 'places_design_scope.dart';
import 'places_strings.dart';

/// Renders the attribution required for a displayed [PlacePhoto]: the author
/// names, and a link to the photo on Google Maps.
///
/// Place this widget adjacent to the corresponding image. It renders nothing
/// when Google returned neither an author name nor a Google Maps link.
/// `PlacePhotoView` draws one itself; use this widget when you show a photo
/// some other way.
///
/// The "View on Google Maps" link ([PlacesStrings.viewOnGoogleMapsText])
/// opens [PlacePhoto.googleMapsUri], and an author's name opens their profile
/// when Google returned one. Google requires users to be able to open the
/// photo on Google Maps — see the
/// [Places API policies](https://developers.google.com/maps/documentation/places/web-service/policies).
/// Pass [onOpenLink] so the links work on every platform.
class PlacesPhotoAttribution extends StatefulWidget {
  /// Creates a required photo attribution label.
  const PlacesPhotoAttribution({
    super.key,
    required this.photo,
    @Deprecated(
      'Use strings: PlacesStrings(photoAttributionPrefix: ...). '
      'Will be removed in 1.0.0.',
    )
    this.prefix,
    this.strings = const PlacesStrings(),
    this.style,
    this.onOpenLink,
  });

  /// Photo whose attribution should be rendered.
  final PlacePhoto photo;

  /// Text placed before the returned author names. When set, it replaces
  /// [PlacesStrings.photoAttributionPrefix].
  @Deprecated(
    'Use strings: PlacesStrings(photoAttributionPrefix: ...). '
    'Will be removed in 1.0.0.',
  )
  final String? prefix;

  /// The widget's strings: [PlacesStrings.photoAttributionPrefix] is placed
  /// before the author names, and [PlacesStrings.viewOnGoogleMapsText] is the
  /// Google Maps link.
  final PlacesStrings strings;

  /// Optional text style. Links are drawn in it, underlined.
  final TextStyle? style;

  /// Opens a link the user taps: the photo on Google Maps, or an author's
  /// Google Maps profile.
  ///
  /// The package cannot open a link itself on Android, iOS, macOS, Windows or
  /// Linux, since that needs a plugin, so pass this — for example
  /// `onOpenLink: (uri) => launchUrl(uri)`, with `url_launcher` in your app.
  /// It receives only `https` and `http` links.
  ///
  /// When it is `null`: on web, a link opens in a new browser tab; on other
  /// platforms, no link is shown — the author names are plain text — and a
  /// debug notice is printed once per app run.
  final ValueChanged<Uri>? onOpenLink;

  @override
  State<PlacesPhotoAttribution> createState() => _PlacesPhotoAttributionState();
}

class _PlacesPhotoAttributionState extends State<PlacesPhotoAttribution> {
  final Map<Uri, TapGestureRecognizer> _recognizers =
      <Uri, TapGestureRecognizer>{};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  // ponytail: span links are reachable by touch, mouse and screen readers but
  // not by Tab; use focusable buttons if keyboard users ask for it.
  TextSpan _link(
    String text,
    Uri? uri,
    ValueChanged<Uri>? open,
    Set<Uri> used,
  ) {
    if (uri == null || open == null) {
      return TextSpan(text: text);
    }
    used.add(uri);
    // Kept across builds, so a rebuild mid-tap does not drop the tap.
    final recognizer = _recognizers.putIfAbsent(uri, TapGestureRecognizer.new)
      ..onTap = () => open(uri);
    return TextSpan(
      text: text,
      recognizer: recognizer,
      style: const TextStyle(decoration: TextDecoration.underline),
    );
  }

  @override
  Widget build(BuildContext context) {
    final used = <Uri>{};
    final content = _content(used);
    _recognizers.removeWhere((uri, recognizer) {
      final unused = !used.contains(uri);
      if (unused) {
        recognizer.dispose();
      }
      return unused;
    });
    return content;
  }

  Widget _content(Set<Uri> used) {
    final photo = widget.photo;
    final open = photoLinkOpener(widget.onOpenLink, photo);
    final authors = photo.authors
        .where((author) => author.displayName.trim().isNotEmpty)
        .toList(growable: false);
    final mapsLink = open == null ? null : safePhotoLink(photo.googleMapsUri);
    if (authors.isEmpty && mapsLink == null) {
      return const SizedBox.shrink();
    }
    final spans = <InlineSpan>[
      if (authors.isNotEmpty)
        TextSpan(
          text: '${widget.prefix ?? widget.strings.photoAttributionPrefix} ',
        ),
      for (final (index, author) in authors.indexed) ...<InlineSpan>[
        if (index > 0) const TextSpan(text: ', '),
        _link(author.displayName.trim(), safePhotoLink(author.uri), open, used),
      ],
      if (mapsLink != null) ...<InlineSpan>[
        if (authors.isNotEmpty) const TextSpan(text: ' · '),
        _link(widget.strings.viewOnGoogleMapsText, mapsLink, open, used),
      ],
    ];
    // Google requires the attribution to be legible, so in an app without
    // material_ui the text still follows the app's brightness.
    return PlacesDesignScope(
      child: Builder(
        builder: (context) => Text.rich(
          TextSpan(children: spans),
          style: widget.style ?? Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
