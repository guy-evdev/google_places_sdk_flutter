import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_builders.dart';
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
  ///
  /// Exactly one of `client` and `apiKey` must be supplied; see
  /// [PlacesAutocompleteField.client] and [PlacesAutocompleteField.apiKey].
  PlacesAutocompleteFormField({
    super.key,
    PlacesClient? client,
    String? apiKey,
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
    bool includeFutureOpeningBusinesses = false,
    bool fetchPlaceDetailsOnSelection = true,
    bool fetchTimeZoneOnSelection = false,
    Set<PlaceField> selectionFields = PlaceFieldPresets.address,
    String? selectionLanguageCode,
    String? selectionRegionCode,
    DateTime? selectionTimeZoneAt,
    String? selectionTimeZoneLanguageCode,
    PlacesAutocompleteFieldMode fieldMode = PlacesAutocompleteFieldMode.inline,
    ValueChanged<PlaceSelection>? onSelection,
    VoidCallback? onClearField,
    ValueChanged<Object>? onError,
    int maxSuggestions = 5,
    int minInputLength = 1,
    Duration? debounceDuration,
    super.enabled = true,
    bool autofocus = false,
    bool unfocusOnSelection = true,
    OptionsViewOpenDirection suggestionsViewOpenDirection =
        OptionsViewOpenDirection.mostSpace,
    bool showPoweredByGoogle = true,
    bool includeQueryPredictions = false,
    ValueChanged<QuerySuggestion>? onQuerySelection,
    TextInputType keyboardType = TextInputType.streetAddress,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextStyle? style,
    TextAlign textAlign = TextAlign.start,
    TextDirection? textDirection,
    bool? autocorrect,
    bool enableSuggestions = true,
    bool enableIMEPersonalizedLearning = true,
    List<TextInputFormatter>? inputFormatters,
    int? maxLength,
    MaxLengthEnforcement? maxLengthEnforcement,
    Iterable<String>? autofillHints = const <String>[],
    Brightness? keyboardAppearance,
    EdgeInsets scrollPadding = const EdgeInsets.all(20),
    ValueChanged<String>? onSubmitted,
    VoidCallback? onEditingComplete,
    PlacesFieldBuilder? fieldBuilder,
    PlacesSuggestionItemBuilder? suggestionItemBuilder,
    PlacesSuggestionsViewBuilder? suggestionsViewBuilder,
    @Deprecated(
      'Use suggestionItemBuilder, which builds the whole row. '
      'suggestionBuilder is deprecated in 0.7.0 and will be removed in 1.0.0.',
    )
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
  }) : assert(
         (client == null) != (apiKey == null),
         'Pass exactly one of client or apiKey.',
       ),
       assert(
         suggestionBuilder == null || suggestionItemBuilder == null,
         'Pass suggestionItemBuilder or the deprecated suggestionBuilder, '
         'not both.',
       ),
       assert(minInputLength >= 1, 'minInputLength must be at least 1.'),
       super(
         builder: (FormFieldState<PlaceSelection?> field) {
           final errorText = field.errorText;
           // A custom field gets the message as PlacesFieldData.errorText;
           // errorBuilder styles the default field's error only.
           final buildsError = errorBuilder != null && fieldBuilder == null;
           final effectiveDecoration = (decoration ?? const InputDecoration())
               .copyWith(
                 errorText: buildsError ? null : errorText,
                 error: buildsError && errorText != null
                     ? errorBuilder(field.context, errorText)
                     : null,
               );
           return _ControllerBinding(
             externalController: controller,
             value: field.value,
             builder: (effectiveController) => PlacesAutocompleteField(
               client: client,
               apiKey: apiKey,
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
               includeFutureOpeningBusinesses: includeFutureOpeningBusinesses,
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
               minInputLength: minInputLength,
               debounceDuration: debounceDuration,
               enabled: enabled,
               autofocus: autofocus,
               unfocusOnSelection: unfocusOnSelection,
               suggestionsViewOpenDirection: suggestionsViewOpenDirection,
               showPoweredByGoogle: showPoweredByGoogle,
               includeQueryPredictions: includeQueryPredictions,
               onQuerySelection: onQuerySelection,
               keyboardType: keyboardType,
               textInputAction: textInputAction,
               textCapitalization: textCapitalization,
               style: style,
               textAlign: textAlign,
               textDirection: textDirection,
               autocorrect: autocorrect,
               enableSuggestions: enableSuggestions,
               enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
               inputFormatters: inputFormatters,
               maxLength: maxLength,
               maxLengthEnforcement: maxLengthEnforcement,
               autofillHints: autofillHints,
               keyboardAppearance: keyboardAppearance,
               scrollPadding: scrollPadding,
               onSubmitted: onSubmitted,
               onEditingComplete: onEditingComplete,
               fieldBuilder: fieldBuilder,
               suggestionItemBuilder: suggestionItemBuilder,
               suggestionsViewBuilder: suggestionsViewBuilder,
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
