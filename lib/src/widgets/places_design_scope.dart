import 'package:material_ui/material_ui.dart';

/// Lets the package's widgets build in an app that does not use `material_ui`,
/// such as an app still on the in-framework `package:flutter/material.dart`.
///
/// `material_ui` widgets need `material_ui`'s own [MaterialLocalizations] and a
/// `material_ui` [Material] ancestor. A legacy app provides only the
/// in-framework types of the same names, which are different types. When no
/// `material_ui` [MaterialLocalizations] is found above it, this scope supplies
/// both, with `material_ui`'s default theme. In a `material_ui` app it returns
/// [child] unchanged.
///
/// Apply it at every root the package builds: anything built outside the
/// field's own subtree — routes, and overlay entries such as the text
/// field's context menu — does not see the field's scope.
class PlacesDesignScope extends StatelessWidget {
  /// Wraps [child] in the scope.
  const PlacesDesignScope({super.key, required this.child});

  /// The subtree that needs `material_ui` ancestors.
  final Widget child;

  static final ThemeData _lightTheme = ThemeData();
  static final ThemeData _darkTheme = ThemeData(brightness: Brightness.dark);
  static bool _noticeShown = false;

  /// Lets tests observe the once-per-run debug notice again.
  @visibleForTesting
  static void debugResetNotice() => _noticeShown = false;

  /// Whether [context] has `material_ui` localizations above it.
  static bool hasMaterialUiAncestors(BuildContext context) =>
      Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) !=
      null;

  /// The scope's [TextField.contextMenuBuilder]: the long-press menu is built
  /// in the root overlay, outside the field's scope, so it needs its own.
  static Widget contextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    // Same choice TextField makes by default.
    return PlacesDesignScope(
      child: SystemContextMenu.isSupportedByField(editableTextState)
          ? SystemContextMenu.editableText(editableTextState: editableTextState)
          : AdaptiveTextSelectionToolbar.editableText(
              editableTextState: editableTextState,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (hasMaterialUiAncestors(context)) {
      return child;
    }
    assert(_debugShowNoticeOnce());
    Widget scoped = Material(type: MaterialType.transparency, child: child);
    // An app that wraps the field in material_ui's own Theme keeps it: that is
    // how an unmigrated app can style the field.
    if (context.findAncestorWidgetOfExactType<Theme>() == null) {
      // ponytail: brightness is read from the ambient IconTheme, which a
      // legacy Theme derives from its brightness — the only theme signal
      // reachable without importing the legacy library. Inside a coloured bar,
      // or with iconTheme.color set against the brightness, it picks the other
      // default. Mapping the full legacy theme needs that import; rejected.
      final iconColor = IconTheme.of(context).color;
      final dark = iconColor != null && iconColor.computeLuminance() > 0.5;
      scoped = Theme(data: dark ? _darkTheme : _lightTheme, child: scoped);
    }
    // ponytail: Localizations.override reloads the app's own delegates in a new
    // Localizations, which renders nothing until they load. Synchronous
    // delegates (the global ones, gen-l10n) load in the same frame; an app
    // delegate that loads asynchronously blanks this subtree until it does.
    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        ...GlobalMaterialLocalizations.delegates,
        _AnyLocaleMaterialLocalizationsDelegate(),
      ],
      child: scoped,
    );
  }

  static bool _debugShowNoticeOnce() {
    if (!_noticeShown) {
      _noticeShown = true;
      debugPrint(
        'google_places_sdk_flutter: this app does not use material_ui, so the '
        "Places widgets use material_ui's default theme, following the app's "
        "brightness. To style them, wrap them in material_ui's Theme, or "
        "migrate the app to use its own theme: "
        '`dart fix --apply --code=migrate_design_widgets`.',
      );
    }
    return true;
  }
}

/// English material_ui localizations for any locale the global delegates do
/// not cover, so the widgets still build. DefaultMaterialLocalizations.delegate
/// itself accepts only `en`.
class _AnyLocaleMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_AnyLocaleMaterialLocalizationsDelegate old) => false;
}
