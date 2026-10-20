// The one place package:flutter/material.dart may appear: these tests host the
// package's widgets in an app that has not migrated to material_ui, and prove
// they build there with no app code. The import is prefixed so every
// unprefixed Material name below is material_ui's.
// ignore_for_file: deprecated_member_use
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:google_places_sdk_flutter/src/widgets/places_design_scope.dart';
import 'package:material_ui/material_ui.dart';

class _FakeBackend implements PlacesBackend {
  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceSuggestion>[
    PlaceSuggestion(
      placeId: 'place-1',
      placeResourceName: 'places/place-1',
      fullText: StructuredText(text: 'Coffee Lab, Main Street'),
      primaryText: StructuredText(text: 'Coffee Lab'),
      secondaryText: StructuredText(text: 'Main Street'),
    ),
  ];

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const PlaceData(id: 'place-1', formattedAddress: 'Main Street');

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {}

  @override
  Future<void> close() async {}

  // Nothing else is reached by these tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PlacesClient _client() =>
    PlacesClient.testing(apiKey: 'test', backend: _FakeBackend());

/// A legacy app: in-framework MaterialApp, Scaffold, and theme, with no
/// material_ui ancestor of any kind.
Widget _legacyApp(Widget body, {legacy.ThemeData? theme}) => legacy.MaterialApp(
  theme: theme,
  home: legacy.Scaffold(body: body),
);

Future<void> _searchAndSelect(WidgetTester tester, Finder scope) async {
  await tester.enterText(
    find.descendant(of: scope, matching: find.byType(TextField)),
    'cof',
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Coffee Lab'));
  await tester.pumpAndSettle();
}

// debugPrint must be restored inside the test body, before flutter_test
// checks its foundation invariants.
Future<List<String?>> _capturePrints(Future<void> Function() body) async {
  final printed = <String?>[];
  final originalDebugPrint = debugPrint;
  debugPrint = (message, {wrapWidth}) => printed.add(message);
  try {
    await body();
  } finally {
    debugPrint = originalDebugPrint;
  }
  return printed;
}

void main() {
  setUp(PlacesDesignScope.debugResetNotice);

  testWidgets('inline field searches and selects in a legacy app', (
    tester,
  ) async {
    PlaceSelection? selection;
    await tester.pumpWidget(
      _legacyApp(
        PlacesAutocompleteField(
          client: _client(),
          onSelection: (value) => selection = value,
        ),
      ),
    );

    await _searchAndSelect(tester, find.byType(PlacesAutocompleteField));

    expect(tester.takeException(), isNull);
    expect(selection?.placeId, 'place-1');
  });

  testWidgets('the long-press menu builds in a legacy app', (tester) async {
    await tester.pumpWidget(
      _legacyApp(PlacesAutocompleteField(client: _client())),
    );
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  }, skip: kIsWeb); // The browser supplies its own context menu on web.

  for (final fieldMode in <PlacesAutocompleteFieldMode>[
    PlacesAutocompleteFieldMode.dialog,
    PlacesAutocompleteFieldMode.fullscreen,
  ]) {
    testWidgets('${fieldMode.name} mode opens and selects in a legacy app', (
      tester,
    ) async {
      PlaceSelection? selection;
      await tester.pumpWidget(
        _legacyApp(
          PlacesAutocompleteField(
            client: _client(),
            fieldMode: fieldMode,
            onSelection: (value) => selection = value,
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(PlacesAutocompleteOverlay), findsOneWidget);
      await _searchAndSelect(tester, find.byType(PlacesAutocompleteOverlay));

      expect(tester.takeException(), isNull);
      expect(find.byType(PlacesAutocompleteOverlay), findsNothing);
      expect(selection?.placeId, 'place-1');
    });
  }

  for (final mode in PlacesAutocompleteOverlayMode.values) {
    testWidgets('show() in ${mode.name} mode from a legacy context', (
      tester,
    ) async {
      Future<PlaceSelection?>? result;
      await tester.pumpWidget(
        _legacyApp(
          legacy.Builder(
            builder: (context) => legacy.TextButton(
              onPressed: () {
                result = PlacesAutocompleteOverlay.show(
                  context,
                  client: _client(),
                  mode: mode,
                );
              },
              child: const legacy.Text('Pick'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Pick'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _searchAndSelect(tester, find.byType(PlacesAutocompleteOverlay));

      expect(tester.takeException(), isNull);
      expect((await result)?.placeId, 'place-1');
    });
  }

  testWidgets('the form field validates in a legacy app', (tester) async {
    final formKey = legacy.GlobalKey<legacy.FormState>();
    await tester.pumpWidget(
      _legacyApp(
        legacy.Form(
          key: formKey,
          child: PlacesAutocompleteFormField(
            client: _client(),
            validator: (value) => value == null ? 'Pick a place' : null,
          ),
        ),
      ),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Pick a place'), findsOneWidget);

    await _searchAndSelect(tester, find.byType(PlacesAutocompleteFormField));

    expect(tester.takeException(), isNull);
    expect(formKey.currentState!.validate(), isTrue);
  });

  testWidgets("follows a dark legacy app's brightness", (tester) async {
    await tester.pumpWidget(
      _legacyApp(
        PlacesAutocompleteField(client: _client()),
        theme: legacy.ThemeData.dark(),
      ),
    );

    final fieldContext = tester.element(find.byType(TextField));
    expect(Theme.of(fieldContext).brightness, Brightness.dark);
  });

  testWidgets('builds for a locale material_ui does not translate', (
    tester,
  ) async {
    await tester.pumpWidget(
      legacy.MaterialApp(
        locale: const Locale('tlh'),
        supportedLocales: const <Locale>[Locale('tlh')],
        home: legacy.Scaffold(body: PlacesAutocompleteField(client: _client())),
      ),
    );

    // Flutter warns that no delegate translates `tlh` — a warning, not a
    // failure; the field must still build, in English.
    expect(tester.takeException(), contains('is not supported'));
    expect(find.byType(TextField), findsOneWidget);
    expect(
      MaterialLocalizations.of(tester.element(find.byType(TextField))),
      isA<DefaultMaterialLocalizations>(),
    );
  });

  testWidgets("keeps a material_ui Theme the app wraps around the field", (
    tester,
  ) async {
    final fieldTheme = ThemeData(colorSchemeSeed: const Color(0xFF00897B));
    await tester.pumpWidget(
      _legacyApp(
        Theme(
          data: fieldTheme,
          child: PlacesAutocompleteField(client: _client()),
        ),
      ),
    );

    final fieldContext = tester.element(find.byType(TextField));
    expect(
      Theme.of(fieldContext).colorScheme.primary,
      fieldTheme.colorScheme.primary,
    );
  });

  testWidgets('photo attribution is legible in a dark legacy app', (
    tester,
  ) async {
    const photo = PlacePhoto(
      name: 'places/place-1/photos/photo-1',
      widthPx: 800,
      heightPx: 600,
      authors: <PlacePhotoAuthorAttribution>[
        PlacePhotoAuthorAttribution(displayName: 'A. Photographer'),
      ],
    );
    await tester.pumpWidget(
      _legacyApp(
        const PlacesPhotoAttribution(photo: photo),
        theme: legacy.ThemeData.dark(),
      ),
    );

    final text = tester.widget<Text>(find.textContaining('A. Photographer'));
    expect(text.style?.color?.computeLuminance(), greaterThan(0.5));
  });

  testWidgets('prints its debug notice once per run', (tester) async {
    final printed = await _capturePrints(
      () => tester.pumpWidget(
        _legacyApp(
          Column(
            children: <Widget>[
              PlacesAutocompleteField(client: _client()),
              PlacesAutocompleteField(client: _client()),
            ],
          ),
        ),
      ),
    );

    expect(printed, hasLength(1));
    expect(printed.single, contains('migrate_design_widgets'));
    expect(printed.single, contains('fieldBuilder'));
  });

  testWidgets('does nothing in a material_ui app', (tester) async {
    final appTheme = ThemeData(colorSchemeSeed: const Color(0xFF00897B));

    final printed = await _capturePrints(
      () => tester.pumpWidget(
        MaterialApp(
          theme: appTheme,
          home: Scaffold(body: PlacesAutocompleteField(client: _client())),
        ),
      ),
    );

    final fieldContext = tester.element(find.byType(TextField));
    expect(
      Theme.of(fieldContext).colorScheme.primary,
      appTheme.colorScheme.primary,
    );
    expect(printed, isEmpty);
  });

  for (final fieldMode in PlacesAutocompleteFieldMode.values) {
    testWidgets('fieldBuilder returns the app\'s own field and theme, '
        '${fieldMode.name} mode', (tester) async {
      final appTheme = legacy.ThemeData(primaryColor: const Color(0xFFAD1457));
      PlaceSelection? selection;
      await tester.pumpWidget(
        _legacyApp(
          PlacesAutocompleteField(
            client: _client(),
            fieldMode: fieldMode,
            onSelection: (value) => selection = value,
            // A legacy Material above it, as the dartdoc says: the package's
            // dialog and fullscreen search are material_ui surfaces.
            fieldBuilder: (context, field) => legacy.Material(
              type: legacy.MaterialType.transparency,
              child: legacy.TextField(
                controller: field.controller,
                focusNode: field.focusNode,
                onChanged: field.onChanged,
                onTap: field.onTap,
                readOnly: field.readOnly,
                autofocus: field.autofocus,
              ),
            ),
          ),
          theme: appTheme,
        ),
      );
      final Finder scope;
      if (fieldMode == PlacesAutocompleteFieldMode.inline) {
        scope = find.byType(PlacesAutocompleteField);
      } else {
        await tester.tap(find.byType(legacy.TextField));
        await tester.pumpAndSettle();
        scope = find.byType(PlacesAutocompleteOverlay);
      }
      final legacyField = find.descendant(
        of: scope,
        matching: find.byType(legacy.TextField),
      );

      expect(
        legacy.Theme.of(tester.element(legacyField)).primaryColor,
        appTheme.primaryColor,
      );
      await tester.enterText(legacyField, 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coffee Lab'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(selection?.placeId, 'place-1');
    });
  }
}
