import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import 'places_design_scope.dart';
import 'places_strings.dart';

/// Renders the author attribution required for a displayed [PlacePhoto].
///
/// Place this widget adjacent to the corresponding image. It renders nothing
/// when Google did not return an author attribution. `PlacePhotoView` draws
/// one itself; use this widget when you show a photo some other way.
class PlacesPhotoAttribution extends StatelessWidget {
  /// Creates a required photo-author attribution label.
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
  });

  /// Photo whose author attribution should be rendered.
  final PlacePhoto photo;

  /// Text placed before the returned author names. When set, it replaces
  /// [PlacesStrings.photoAttributionPrefix].
  @Deprecated(
    'Use strings: PlacesStrings(photoAttributionPrefix: ...). '
    'Will be removed in 1.0.0.',
  )
  final String? prefix;

  /// The widget's strings; [PlacesStrings.photoAttributionPrefix] is placed
  /// before the author names.
  final PlacesStrings strings;

  /// Optional text style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final names = photo.authors
        .map((author) => author.displayName.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (names.isEmpty) {
      return const SizedBox.shrink();
    }
    // ignore: deprecated_member_use_from_same_package
    final label =
        '${prefix ?? strings.photoAttributionPrefix} '
        '${names.join(', ')}';
    // Google requires the attribution to be legible, so in an app without
    // material_ui the text still follows the app's brightness.
    return PlacesDesignScope(
      child: Builder(
        builder: (context) => Semantics(
          label: label,
          child: Text(
            label,
            style: style ?? Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
