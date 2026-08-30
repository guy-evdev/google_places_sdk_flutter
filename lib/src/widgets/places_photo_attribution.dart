import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';

/// Renders the author attribution required for a displayed [PlacePhoto].
///
/// Place this widget adjacent to the corresponding image. It renders nothing
/// when Google did not return an author attribution.
class PlacesPhotoAttribution extends StatelessWidget {
  /// Creates a required photo-author attribution label.
  const PlacesPhotoAttribution({
    super.key,
    required this.photo,
    this.prefix = 'Photo by',
    this.style,
  });

  /// Photo whose author attribution should be rendered.
  final PlacePhoto photo;

  /// Localizable text placed before the returned author names.
  final String prefix;

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
    final label = '$prefix ${names.join(', ')}';
    return Semantics(
      label: label,
      child: Text(label, style: style ?? Theme.of(context).textTheme.bodySmall),
    );
  }
}
