import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';

class _FakeBackend implements PlacesBackend {
  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request,
  ) async {
    return <PlaceSuggestion>[
      PlaceSuggestion(
        placeId: 'place-1',
        placeResourceName: 'places/place-1',
        fullText: const StructuredText(text: 'Coffee Lab, Main Street'),
        primaryText: const StructuredText(text: 'Coffee Lab'),
        secondaryText: const StructuredText(text: 'Main Street'),
      ),
      for (var index = 2; index <= 10; index++)
        PlaceSuggestion(
          placeId: 'place-$index',
          placeResourceName: 'places/place-$index',
          fullText: StructuredText(text: 'Coffee Lab $index, Main Street'),
          primaryText: StructuredText(text: 'Coffee Lab $index'),
          secondaryText: const StructuredText(text: 'Main Street'),
        ),
    ];
  }

  @override
  Future<void> close() async {}

  @override
  Future<PlaceData> fetchPlace(PlaceDetailsRequest request) async {
    return const PlaceData(
      id: 'place-1',
      displayName: LocalizedText(text: 'Coffee Lab'),
      formattedAddress: 'Main Street',
      location: PlaceCoordinates(latitude: 40.7128, longitude: -74.0060),
    );
  }

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(TimeZoneRequest request) async {
    return PlaceTimeZoneData(
      dstOffset: const Duration(hours: 1),
      rawOffset: const Duration(hours: -5),
      timeZoneId: 'America/New_York',
      timeZoneName: 'Eastern Daylight Time',
      timestamp: request.timestamp ?? DateTime.utc(2026, 4, 15),
      rawData: const <String, Object?>{
        'dstOffset': 3600,
        'rawOffset': -18000,
        'timeZoneId': 'America/New_York',
        'timeZoneName': 'Eastern Daylight Time',
        'status': 'OK',
      },
    );
  }

  @override
  Future<List<PlaceData>> searchNearby(NearbySearchRequest request) async =>
      const <PlaceData>[];

  @override
  Future<List<PlaceData>> searchText(TextSearchRequest request) async =>
      const <PlaceData>[];
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int pushCount = 0;
  int popCount = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushCount++;
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    popCount++;
    super.didPop(route, previousRoute);
  }
}

void main() {
  testWidgets('renders custom strings and suggestion results', (tester) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            strings: const PlacesStrings(searchHint: 'Search demo'),
          ),
        ),
      ),
    );

    expect(find.text('Search demo'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Coffee Lab'), findsOneWidget);
    expect(find.text('Main Street'), findsWidgets);
  });

  testWidgets('emits a unified selection with resolved place data', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    PlaceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            fetchPlaceDetailsOnSelection: true,
            selectionFields: PlaceFieldPresets.rich,
            onSelection: (value) {
              selection = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(selection, isNotNull);
    expect(selection!.suggestion.placeId, 'place-1');
    expect(selection!.place, isNotNull);
    expect(selection!.place!.formattedAddress, 'Main Street');
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(const PlacesStrings().noResultsText), findsNothing);
    expect(find.text('Main Street'), findsNothing);
  });

  testWidgets('can enrich the selection with time-zone data', (tester) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    PlaceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            fetchTimeZoneOnSelection: true,
            selectionFields: PlaceFieldPresets.minimal,
            onSelection: (value) {
              selection = value;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coffee Lab'));
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.place, isNotNull);
    expect(selection!.timeZone, isNotNull);
    expect(selection!.timeZone!.timeZoneId, 'America/New_York');
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('clear button clears the field and calls onClearField', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    final controller = PlacesAutocompleteController(initialText: 'Coffee Lab');
    var didClear = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            controller: controller,
            onClearField: () {
              didClear = true;
            },
          ),
        ),
      ),
    );

    expect(controller.textController.text, 'Coffee Lab');

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(controller.textController.text, isEmpty);
    expect(didClear, isTrue);
  });

  testWidgets(
    'merges user decoration styling with package hint and clear button',
    (tester) async {
      final client = PlacesClient.testing(
        apiKey: 'test',
        backend: _FakeBackend(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              client: client,
              strings: const PlacesStrings(searchHint: 'Search demo'),
              decoration: const InputDecoration(
                labelText: 'Place',
                border: OutlineInputBorder(),
                floatingLabelBehavior: FloatingLabelBehavior.always,
                suffixIcon: Icon(Icons.favorite),
              ),
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      final decoration = textField.decoration!;

      expect(decoration.labelText, 'Place');
      expect(decoration.border, isA<OutlineInputBorder>());
      expect(decoration.floatingLabelBehavior, FloatingLabelBehavior.always);
      expect(decoration.hintText, 'Search demo');
      expect(decoration.suffixIcon, isNotNull);
      expect(decoration.suffix, isNotNull);

      expect(find.byIcon(Icons.clear), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    },
  );

  testWidgets(
    'switching from launcher mode back to inline works after opening overlay',
    (tester) async {
      final client = PlacesClient.testing(
        apiKey: 'test',
        backend: _FakeBackend(),
      );
      final controller = PlacesAutocompleteController();
      final navigatorKey = GlobalKey<NavigatorState>();
      var mode = PlacesAutocompleteFieldMode.fullscreen;

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: <Widget>[
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          mode = PlacesAutocompleteFieldMode.inline;
                        });
                      },
                      child: const Text('Switch'),
                    ),
                    PlacesAutocompleteField(
                      client: client,
                      controller: controller,
                      fieldMode: mode,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(find.byType(Scaffold), findsWidgets);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Switch'));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.text('Coffee Lab'), findsOneWidget);
    },
  );

  testWidgets('fullscreen overlay uses the root navigator by default', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    final rootObserver = _RecordingNavigatorObserver();
    final nestedObserver = _RecordingNavigatorObserver();
    late BuildContext nestedContext;

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: <NavigatorObserver>[rootObserver],
        home: Navigator(
          observers: <NavigatorObserver>[nestedObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (context) {
              nestedContext = context;
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      unawaited(
                        PlacesAutocompleteOverlay.show(
                          nestedContext,
                          client: client,
                          mode: PlacesAutocompleteOverlayMode.fullscreen,
                        ),
                      );
                    },
                    child: const Text('Open overlay'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    final initialRootPushes = rootObserver.pushCount;
    final initialNestedPushes = nestedObserver.pushCount;

    await tester.tap(find.text('Open overlay'));
    await tester.pumpAndSettle();

    expect(rootObserver.pushCount, initialRootPushes + 1);
    expect(nestedObserver.pushCount, initialNestedPushes);
  });

  testWidgets(
    'dialog selection dismisses the dialog instead of popping the nested navigator',
    (tester) async {
      final client = PlacesClient.testing(
        apiKey: 'test',
        backend: _FakeBackend(),
      );
      final rootObserver = _RecordingNavigatorObserver();
      final nestedObserver = _RecordingNavigatorObserver();
      PlaceSelection? result;
      late BuildContext nestedContext;

      await tester.pumpWidget(
        MaterialApp(
          navigatorObservers: <NavigatorObserver>[rootObserver],
          home: Navigator(
            observers: <NavigatorObserver>[nestedObserver],
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) {
                nestedContext = context;
                return Scaffold(
                  body: Center(
                    child: FilledButton(
                      onPressed: () async {
                        result = await PlacesAutocompleteOverlay.show(
                          nestedContext,
                          client: client,
                          mode: PlacesAutocompleteOverlayMode.dialog,
                        );
                      },
                      child: const Text('Open dialog'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );

      final initialNestedPops = nestedObserver.popCount;

      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee Lab'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.suggestion.placeId, 'place-1');
      expect(nestedObserver.popCount, initialNestedPops);
      expect(find.byType(Dialog), findsNothing);
    },
  );

  testWidgets('overlay show clamps maxSuggestions to the Google limit', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () {
                unawaited(
                  PlacesAutocompleteOverlay.show(
                    context,
                    client: client,
                    mode: PlacesAutocompleteOverlayMode.dialog,
                    maxSuggestions: 7,
                  ),
                );
              },
              child: const Text('Open dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNWidgets(5));
    expect(find.text('Coffee Lab 6'), findsNothing);
  });
}
