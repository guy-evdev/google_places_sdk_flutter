import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_field.dart';
import 'places_strings.dart';

/// FormField wrapper around [PlacesAutocompleteField].
///
/// The selected [PlaceSelection] participates in validation, saving,
/// restoration, and [FormState.reset]. When no [controller] is supplied this
/// widget owns one and disposes it automatically.
class PlacesAutocompleteFormField extends FormField<PlaceSelection?> {
  /// Creates a Places autocomplete form field.
  PlacesAutocompleteFormField({
    super.key,
    required PlacesClient client,
    PlacesAutocompleteController? controller,
    InputDecoration? decoration,
    PlacesStrings strings = const PlacesStrings(),
    String? languageCode,
    String? regionCode,
    PlaceCoordinates? origin,
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
    PlacesAutocompleteFieldMode fieldMode = PlacesAutocompleteFieldMode.inline,
    ValueChanged<PlaceSelection>? onSelection,
    VoidCallback? onClearField,
    ValueChanged<Object>? onError,
    int maxSuggestions = 5,
    super.enabled = true,
    bool autofocus = false,
    bool showPoweredByGoogle = true,
    bool includeQueryPredictions = false,
    ValueChanged<QuerySuggestion>? onQuerySelection,
    Widget Function(BuildContext context, PlaceSuggestion suggestion)?
    suggestionBuilder,
    super.validator,
    super.onSaved,
    super.initialValue,
    super.autovalidateMode = AutovalidateMode.disabled,
    super.onReset,
    super.forceErrorText,
    super.errorBuilder,
    super.restorationId,
  }) : super(
         builder: (FormFieldState<PlaceSelection?> field) {
           final errorText = field.errorText;
           final effectiveDecoration = (decoration ?? const InputDecoration())
               .copyWith(
                 errorText: errorBuilder == null ? errorText : null,
                 error: errorBuilder != null && errorText != null
                     ? errorBuilder(field.context, errorText)
                     : null,
               );
           return _ControllerBinding(
             externalController: controller,
             value: field.value,
             builder: (effectiveController) => PlacesAutocompleteField(
               client: client,
               controller: effectiveController,
               decoration: effectiveDecoration,
               strings: strings,
               languageCode: languageCode,
               regionCode: regionCode,
               origin: origin,
               locationBias: locationBias,
               locationRestriction: locationRestriction,
               includedPrimaryTypes: includedPrimaryTypes,
               includedRegionCodes: includedRegionCodes,
               includePureServiceAreaBusinesses:
                   includePureServiceAreaBusinesses,
               fetchPlaceDetailsOnSelection: fetchPlaceDetailsOnSelection,
               fetchTimeZoneOnSelection: fetchTimeZoneOnSelection,
               selectionFields: selectionFields,
               selectionLanguageCode: selectionLanguageCode,
               selectionRegionCode: selectionRegionCode,
               selectionTimeZoneAt: selectionTimeZoneAt,
               selectionTimeZoneLanguageCode: selectionTimeZoneLanguageCode,
               fieldMode: fieldMode,
               onSelection: (selection) {
                 field.didChange(selection);
                 onSelection?.call(selection);
               },
               onClearField: () {
                 field.didChange(null);
                 onClearField?.call();
               },
               onError: onError,
               maxSuggestions: maxSuggestions,
               enabled: enabled,
               autofocus: autofocus,
               showPoweredByGoogle: showPoweredByGoogle,
               includeQueryPredictions: includeQueryPredictions,
               onQuerySelection: onQuerySelection,
               suggestionBuilder: suggestionBuilder,
             ),
           );
         },
       );
}

class _ControllerBinding extends StatefulWidget {
  const _ControllerBinding({
    required this.externalController,
    required this.value,
    required this.builder,
  });

  final PlacesAutocompleteController? externalController;
  final PlaceSelection? value;
  final Widget Function(PlacesAutocompleteController controller) builder;

  @override
  State<_ControllerBinding> createState() => _ControllerBindingState();
}

class _ControllerBindingState extends State<_ControllerBinding> {
  PlacesAutocompleteController? _ownedController;
  int _restoreGeneration = 0;

  PlacesAutocompleteController get _controller =>
      widget.externalController ??
      (_ownedController ??= PlacesAutocompleteController());

  @override
  void initState() {
    super.initState();
    final controller = _controller;
    if (widget.externalController == null) {
      controller.restoreSelection(widget.value);
    } else {
      _scheduleRestoreSelection(controller, widget.value);
    }
  }

  @override
  void didUpdateWidget(_ControllerBinding oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.externalController != widget.externalController) {
      _ownedController?.dispose();
      _ownedController = null;
      _scheduleRestoreSelection(_controller, widget.value);
      return;
    }
    if (!identical(oldWidget.value, widget.value) ||
        !identical(_controller.selectedSelection, widget.value)) {
      _scheduleRestoreSelection(_controller, widget.value);
    }
  }

  void _scheduleRestoreSelection(
    PlacesAutocompleteController controller,
    PlaceSelection? value,
  ) {
    final generation = ++_restoreGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _restoreGeneration ||
          !identical(controller, _controller)) {
        return;
      }
      controller.restoreSelection(value);
    });
  }

  @override
  void dispose() {
    _restoreGeneration++;
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}
