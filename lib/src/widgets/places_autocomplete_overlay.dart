import 'package:flutter/material.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_field.dart';
import 'places_strings.dart';

/// Presentation mode for [PlacesAutocompleteOverlay].
enum PlacesAutocompleteOverlayMode {
  /// Presents the autocomplete UI inside a dialog route.
  dialog,

  /// Presents the autocomplete UI as a fullscreen route.
  fullscreen,
}

/// Standalone autocomplete search surface shown as a dialog or fullscreen route.
///
/// This wraps [PlacesAutocompleteField] and is useful when the search UI should
/// live in a dedicated route instead of inline.
class PlacesAutocompleteOverlay extends StatelessWidget {
  /// Creates a standalone autocomplete overlay.
  const PlacesAutocompleteOverlay({
    super.key,
    required this.client,
    required this.controller,
    required this.mode,
    this.title,
    this.strings = const PlacesStrings(),
    this.languageCode,
    this.regionCode,
    this.locationBias,
    this.locationRestriction,
    this.includedPrimaryTypes = const <String>[],
    this.includedRegionCodes = const <String>[],
    this.includePureServiceAreaBusinesses = false,
    this.fetchPlaceDetailsOnSelection = false,
    this.fetchTimeZoneOnSelection = false,
    this.selectionFields = PlaceFieldPresets.recommended,
    this.selectionLanguageCode,
    this.selectionRegionCode,
    this.selectionTimeZoneAt,
    this.selectionTimeZoneLanguageCode,
    this.maxSuggestions = 5,
    this.includeQueryPredictions = false,
    this.onSelection,
    this.onQuerySelection,
    this.onError,
  });

  /// Client used to issue autocomplete and optional place-details requests.
  final PlacesClient client;

  /// Controller used by the overlay field.
  final PlacesAutocompleteController controller;

  /// Whether the overlay should be presented as a dialog or fullscreen route.
  final PlacesAutocompleteOverlayMode mode;

  /// Optional title shown above the overlay field.
  final String? title;

  /// Localized strings used by the overlay UI.
  final PlacesStrings strings;

  /// Preferred BCP-47 language code for autocomplete results.
  final String? languageCode;

  /// Preferred CLDR region code for autocomplete results.
  final String? regionCode;

  /// Soft geographic preference applied to autocomplete results.
  final LocationBias? locationBias;

  /// Hard geographic restriction applied to autocomplete results.
  final LocationRestriction? locationRestriction;

  /// Restricts autocomplete results to Google primary place types.
  final List<String> includedPrimaryTypes;

  /// Restricts autocomplete results to the supplied CLDR region codes.
  final List<String> includedRegionCodes;
  final bool includePureServiceAreaBusinesses;

  /// Whether the selected suggestion should be resolved into [PlaceData]
  /// before [onSelection] fires and before [show] completes.
  final bool fetchPlaceDetailsOnSelection;

  /// Whether the selected suggestion should also resolve time-zone metadata.
  ///
  /// This implies place-details resolution because time-zone lookups require
  /// place coordinates.
  final bool fetchTimeZoneOnSelection;

  /// Field set used when [fetchPlaceDetailsOnSelection] is enabled.
  final Set<PlaceField> selectionFields;

  /// Preferred BCP-47 language code for the follow-up place-details request.
  final String? selectionLanguageCode;

  /// Preferred CLDR region code for the follow-up place-details request.
  final String? selectionRegionCode;

  /// Timestamp to use for the optional time-zone lookup.
  final DateTime? selectionTimeZoneAt;

  /// Optional BCP-47 language code for localized time-zone names.
  final String? selectionTimeZoneLanguageCode;

  /// Maximum number of autocomplete suggestions to display.
  ///
  /// Google Autocomplete (New) returns at most five predictions, so values
  /// above `5` are clamped to the upstream response limit.
  final int maxSuggestions;

  /// Whether autocomplete should include query suggestions as well as places.
  final bool includeQueryPredictions;

  /// Called when the user selects a suggestion, optionally with resolved place
  /// details.
  final ValueChanged<PlaceSelection>? onSelection;

  /// Called when the user selects a query suggestion.
  final ValueChanged<QuerySuggestion>? onQuerySelection;

  /// Called when autocomplete, place-details, or time-zone loading fails.
  final ValueChanged<Object>? onError;

  /// Opens a Places autocomplete overlay and returns the user’s selection.
  ///
  /// If [controller] is omitted, the overlay creates and disposes an internal
  /// controller. Use [initialText] to seed the overlay input when launching
  /// from an existing field value.
  ///
  /// This is useful for field-launcher flows where the actual editing
  /// experience should happen in a dialog or fullscreen route.
  static Future<PlaceSelection?> show(
    BuildContext context, {
    required PlacesClient client,
    PlacesAutocompleteController? controller,
    String initialText = '',
    PlacesAutocompleteOverlayMode mode = PlacesAutocompleteOverlayMode.dialog,
    bool useRootNavigator = true,
    PlacesStrings strings = const PlacesStrings(),
    String? title,
    String? languageCode,
    String? regionCode,
    LocationBias? locationBias,
    LocationRestriction? locationRestriction,
    List<String> includedPrimaryTypes = const <String>[],
    List<String> includedRegionCodes = const <String>[],
    bool includePureServiceAreaBusinesses = false,
    bool fetchPlaceDetailsOnSelection = false,
    bool fetchTimeZoneOnSelection = false,
    Set<PlaceField> selectionFields = PlaceFieldPresets.recommended,
    String? selectionLanguageCode,
    String? selectionRegionCode,
    DateTime? selectionTimeZoneAt,
    String? selectionTimeZoneLanguageCode,
    int maxSuggestions = 5,
    bool includeQueryPredictions = false,
    ValueChanged<PlaceSelection>? onSelection,
    ValueChanged<QuerySuggestion>? onQuerySelection,
    ValueChanged<Object>? onError,
  }) async {
    final ownedController = controller == null
        ? PlacesAutocompleteController(initialText: initialText)
        : null;
    final effectiveController = controller ?? ownedController!;
    final navigator = Navigator.of(context, rootNavigator: useRootNavigator);
    final child = PlacesAutocompleteOverlay(
      client: client,
      controller: effectiveController,
      mode: mode,
      title: title,
      strings: strings,
      languageCode: languageCode,
      regionCode: regionCode,
      locationBias: locationBias,
      locationRestriction: locationRestriction,
      includedPrimaryTypes: includedPrimaryTypes,
      includedRegionCodes: includedRegionCodes,
      includePureServiceAreaBusinesses: includePureServiceAreaBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      includeQueryPredictions: includeQueryPredictions,
      onSelection: (selection) {
        navigator.pop(selection);
        onSelection?.call(selection);
      },
      onQuerySelection: onQuerySelection,
      onError: onError,
    );

    try {
      if (mode == PlacesAutocompleteOverlayMode.fullscreen) {
        return await navigator.push<PlaceSelection>(
          MaterialPageRoute<PlaceSelection>(
            builder: (_) => child,
            fullscreenDialog: true,
          ),
        );
      }

      return await showDialog<PlaceSelection>(
        context: context,
        useRootNavigator: useRootNavigator,
        builder: (dialogContext) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );
    } finally {
      if (ownedController != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ownedController.dispose();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final field = PlacesAutocompleteField(
      client: client,
      controller: controller,
      strings: strings,
      languageCode: languageCode,
      regionCode: regionCode,
      locationBias: locationBias,
      locationRestriction: locationRestriction,
      includedPrimaryTypes: includedPrimaryTypes,
      includedRegionCodes: includedRegionCodes,
      includePureServiceAreaBusinesses: includePureServiceAreaBusinesses,
      fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
      fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
      selectionFields: selectionFields,
      selectionLanguageCode: selectionLanguageCode,
      selectionRegionCode: selectionRegionCode,
      selectionTimeZoneAt: selectionTimeZoneAt,
      selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
      maxSuggestions: maxSuggestions,
      includeQueryPredictions: includeQueryPredictions,
      onSelection: onSelection,
      onQuerySelection: onQuerySelection,
      onError: onError,
      autofocus: true,
    );

    if (mode == PlacesAutocompleteOverlayMode.fullscreen) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: IconButton(
            tooltip: strings.closeLabel,
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
          title: Text(title ?? strings.overlayTitle),
        ),
        body: Padding(padding: const EdgeInsets.all(16), child: field),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title ?? strings.overlayTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: strings.closeLabel,
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 16),
        field,
      ],
    );
  }
}
