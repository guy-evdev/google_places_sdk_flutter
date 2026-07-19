import 'package:flutter/material.dart';

import '../models/place_models.dart';

/// Controller for [PlacesAutocompleteField].
///
/// Holds the text controller, focus node, active autocomplete session token,
/// and the last selected [PlaceSelection].
class PlacesAutocompleteController extends ChangeNotifier {
  /// Creates a controller for coordinating field text, focus, and selection.
  PlacesAutocompleteController({
    String initialText = '',
    this.debounceDuration = const Duration(milliseconds: 300),
  }) : textController = TextEditingController(text: initialText),
       focusNode = FocusNode();

  /// Text controller bound to the active autocomplete field.
  final TextEditingController textController;

  /// Focus node bound to the active autocomplete field.
  final FocusNode focusNode;

  /// Debounce duration used before issuing autocomplete requests.
  final Duration debounceDuration;

  AutocompleteSessionToken _sessionToken = AutocompleteSessionToken.generate();
  PlaceSelection? selectedSelection;

  /// Current autocomplete session token used to group search and selection.
  AutocompleteSessionToken get sessionToken => _sessionToken;

  /// The last selected suggestion, if any.
  PlaceSuggestion? get selectedSuggestion => selectedSelection?.suggestion;

  /// The last resolved place details, if any.
  PlaceData? get selectedPlace => selectedSelection?.place;

  /// Clears the current selection, input text, and autocomplete session.
  void clear() {
    selectedSelection = null;
    textController.clear();
    resetSession(notify: false);
    notifyListeners();
  }

  /// Clears only the selected value while preserving the current input text.
  void clearSelection() {
    if (selectedSelection == null) {
      return;
    }
    selectedSelection = null;
    notifyListeners();
  }

  /// Resets the autocomplete session token for a new search flow.
  void resetSession({bool notify = true}) {
    _sessionToken = AutocompleteSessionToken.generate();
    if (notify) {
      notifyListeners();
    }
  }

  /// Updates the controller with a new [selection].
  void setSelection(PlaceSelection selection, {bool updateText = true}) {
    selectedSelection = selection;
    if (updateText) {
      textController
        ..text = selection.displayText
        ..selection = TextSelection.collapsed(
          offset: selection.displayText.length,
        );
    }
    notifyListeners();
  }

  /// Restores [selection] without beginning a new user selection flow.
  ///
  /// Form wrappers use this to synchronize initial and reset values. Passing
  /// `null` clears both the selected value and visible text.
  void restoreSelection(PlaceSelection? selection) {
    final text = selection?.displayText ?? '';
    final selectionChanged = !identical(selectedSelection, selection);
    final textChanged = textController.text != text;
    if (!selectionChanged && !textChanged) {
      return;
    }

    selectedSelection = selection;
    if (textChanged) {
      textController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    focusNode.dispose();
    super.dispose();
  }
}
