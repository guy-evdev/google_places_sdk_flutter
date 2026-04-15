import 'package:flutter/material.dart';

import '../models/place_models.dart';
import '../places_client.dart';
import 'places_autocomplete_controller.dart';
import 'places_autocomplete_field.dart';
import 'places_strings.dart';

/// FormField wrapper around [PlacesAutocompleteField].
///
/// Use this when autocomplete selection should participate in form validation
/// and saving.
class PlacesAutocompleteFormField extends FormField<PlaceSelection?> {
  PlacesAutocompleteFormField({
    super.key,
    required PlacesClient client,
    PlacesAutocompleteController? controller,
    InputDecoration? decoration,
    PlacesStrings strings = const PlacesStrings(),
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
    PlacesAutocompleteFieldMode fieldMode = PlacesAutocompleteFieldMode.inline,
    ValueChanged<PlaceSelection>? onSelection,
    VoidCallback? onClearField,
    ValueChanged<Object>? onError,
    int maxSuggestions = 5,
    bool enabled = true,
    bool autofocus = false,
    bool showPoweredByGoogle = true,
    Widget Function(BuildContext context, PlaceSuggestion suggestion)?
    suggestionBuilder,
    super.validator,
    super.onSaved,
    super.initialValue,
    super.autovalidateMode = AutovalidateMode.disabled,
  }) : super(
         builder: (FormFieldState<PlaceSelection?> field) {
           final effectiveDecoration = (decoration ?? const InputDecoration())
               .copyWith(errorText: field.errorText);
           return PlacesAutocompleteField(
             client: client,
             controller: controller,
             decoration: effectiveDecoration,
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
             suggestionBuilder: suggestionBuilder,
           );
         },
       );
}
