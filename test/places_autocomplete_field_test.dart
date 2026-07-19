import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';

class _FakeBackend implements PlacesBackend {
  final List<AutocompleteSessionToken> endedSessions =
      <AutocompleteSessionToken>[];
  AutocompleteRequest? lastAutocompleteRequest;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    lastAutocompleteRequest = request;
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
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    final places = await autocomplete(request);
    return <AutocompleteSuggestion>[
      places.first,
      const QuerySuggestion(
        fullText: StructuredText(
          text: 'coffee near me',
          matches: <TextMatch>[TextMatch(startOffset: 0, endOffset: 6)],
        ),
      ),
      ...places.skip(1),
    ];
  }

  @override
  Future<void> close() async {}

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {
    endedSessions.add(token);
  }

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    return const PlaceData(
      id: 'place-1',
      displayName: LocalizedText(text: 'Coffee Lab'),
      formattedAddress: 'Main Street',
      location: PlaceCoordinates(latitude: 40.7128, longitude: -74.0060),
    );
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const PlacePhotoMedia(
    name: 'places/place-1/photos/photo-1/media',
    photoUri: 'https://example.com/photo.jpg',
  );

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
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
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceData>[];

  @override
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceData>[];

  @override
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => TextSearchPage(results: const <PlaceData>[]);
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

class _SlowDetailsBackend extends _FakeBackend {
  final Completer<PlaceData> completer = Completer<PlaceData>();
  int fetchPlaceCount = 0;

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    fetchPlaceCount++;
    return completer.future;
  }
}

class _SlowTimeZoneBackend extends _FakeBackend {
  final Completer<PlaceTimeZoneData> completer = Completer<PlaceTimeZoneData>();
  int fetchTimeZoneCount = 0;

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    fetchTimeZoneCount++;
    return completer.future;
  }
}

class _SlowAutocompleteBackend extends _FakeBackend {
  final Completer<List<PlaceSuggestion>> completer =
      Completer<List<PlaceSuggestion>>();
  int autocompleteCount = 0;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    autocompleteCount++;
    return completer.future;
  }
}

class _RetryBackend extends _FakeBackend {
  int attempts = 0;
  final Completer<List<PlaceSuggestion>> firstAttempt =
      Completer<List<PlaceSuggestion>>();

  void failFirstAttempt() {
    firstAttempt.completeError(
      const PlacesException(
        'Temporary failure.',
        kind: PlacesErrorKind.network,
        retryable: true,
      ),
    );
  }

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    attempts++;
    if (attempts == 1) {
      return firstAttempt.future;
    }
    return super.autocomplete(request, cancellationToken: cancellationToken);
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

  testWidgets('sends the current Unicode cursor offset', (tester) async {
    final backend = _FakeBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(client: client, controller: controller),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), '😀 cafe');
    controller.textController.selection = const TextSelection.collapsed(
      offset: 2,
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(backend.lastAutocompleteRequest, isNotNull);
    expect(backend.lastAutocompleteRequest!.inputOffset, 1);
  });

  testWidgets('emits a unified selection with resolved place data', (
    tester,
  ) async {
    final backend = _FakeBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    final sessionToken = controller.sessionToken;
    PlaceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            controller: controller,
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
    expect(selection!.sessionToken, sessionToken);
    expect(selection!.place, isNotNull);
    expect(selection!.place!.formattedAddress, 'Main Street');
    expect(find.byType(ListTile), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(const PlacesStrings().noResultsText), findsNothing);
    expect(find.text('Main Street'), findsNothing);
    expect(
      backend.endedSessions.map((token) => token.value),
      contains(sessionToken.value),
    );
    expect(controller.sessionToken.value, isNot(sessionToken.value));
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

  testWidgets('clear button is only visible while the field has text', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    expect(find.byIcon(Icons.clear), findsNothing);

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump();

    expect(find.byIcon(Icons.clear), findsOneWidget);
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

      expect(find.byIcon(Icons.favorite), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pump();

      final updatedTextField = tester.widget<TextField>(find.byType(TextField));
      expect(updatedTextField.decoration!.suffix, isNotNull);
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

  testWidgets('shows query suggestions when explicitly enabled', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    QuerySuggestion? querySelection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            includeQueryPredictions: true,
            onQuerySelection: (selection) {
              querySelection = selection;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('coffee near me'), findsOneWidget);

    await tester.tap(find.text('coffee near me'));
    await tester.pumpAndSettle();

    expect(querySelection, isNotNull);
    expect(querySelection!.displayText, 'coffee near me');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'coffee near me',
    );
  });

  testWidgets('Enter selects the highlighted suggestion', (tester) async {
    final backend = _FakeBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    final sessionToken = controller.sessionToken;
    PlaceSelection? selection;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            controller: controller,
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

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(selection, isNotNull);
    expect(selection!.placeId, 'place-1');
    expect(selection!.sessionToken, sessionToken);
    expect(
      backend.endedSessions.map((token) => token.value),
      contains(sessionToken.value),
    );
  });

  testWidgets('external session reset ends the prior backend session', (
    tester,
  ) async {
    final backend = _FakeBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    final initialToken = controller.sessionToken;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(client: client, controller: controller),
        ),
      ),
    );

    controller.resetSession();
    await tester.pump();

    expect(
      backend.endedSessions.map((token) => token.value),
      contains(initialToken.value),
    );
  });

  testWidgets('disposal invalidates an in-flight details selection', (
    tester,
  ) async {
    final backend = _SlowDetailsBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    final sessionToken = controller.sessionToken;
    var selectionCount = 0;
    var errorCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            controller: controller,
            fetchPlaceDetailsOnSelection: true,
            onSelection: (_) => selectionCount++,
            onError: (_) => errorCount++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();
    expect(backend.fetchPlaceCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    backend.completer.complete(const PlaceData(id: 'place-1'));
    await tester.pump();

    expect(selectionCount, 0);
    expect(errorCount, 0);
    expect(
      backend.endedSessions.map((token) => token.value),
      contains(sessionToken.value),
    );
  });

  testWidgets('disposal invalidates an in-flight time-zone selection', (
    tester,
  ) async {
    final backend = _SlowTimeZoneBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    var selectionCount = 0;
    var errorCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            fetchTimeZoneOnSelection: true,
            onSelection: (_) => selectionCount++,
            onError: (_) => errorCount++,
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();
    expect(backend.fetchTimeZoneCount, 1);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    backend.completer.complete(
      PlaceTimeZoneData(
        dstOffset: Duration.zero,
        rawOffset: Duration.zero,
        timeZoneId: 'UTC',
        timeZoneName: 'Coordinated Universal Time',
        timestamp: DateTime.utc(2026, 7, 19),
      ),
    );
    await tester.pump();

    expect(selectionCount, 0);
    expect(errorCount, 0);
  });

  testWidgets('replacing the client invalidates an in-flight selection', (
    tester,
  ) async {
    final firstBackend = _SlowDetailsBackend();
    final firstClient = PlacesClient.testing(
      apiKey: 'first',
      backend: firstBackend,
    );
    final secondClient = PlacesClient.testing(
      apiKey: 'second',
      backend: _FakeBackend(),
    );
    var selectionCount = 0;

    Widget buildField(PlacesClient client) {
      return MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            key: const ValueKey<String>('field'),
            client: client,
            fetchPlaceDetailsOnSelection: true,
            onSelection: (_) => selectionCount++,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildField(firstClient));
    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();
    expect(firstBackend.fetchPlaceCount, 1);

    await tester.pumpWidget(buildField(secondClient));
    firstBackend.completer.complete(const PlaceData(id: 'place-1'));
    await tester.pump();

    expect(selectionCount, 0);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('replacing the client rejects stale autocomplete results', (
    tester,
  ) async {
    final firstBackend = _SlowAutocompleteBackend();
    final firstClient = PlacesClient.testing(
      apiKey: 'first',
      backend: firstBackend,
    );
    final secondClient = PlacesClient.testing(
      apiKey: 'second',
      backend: _FakeBackend(),
    );

    Widget buildField(PlacesClient client) {
      return MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            key: const ValueKey<String>('field'),
            client: client,
          ),
        ),
      );
    }

    await tester.pumpWidget(buildField(firstClient));
    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    expect(firstBackend.autocompleteCount, 1);

    await tester.pumpWidget(buildField(secondClient));
    firstBackend.completer.complete(<PlaceSuggestion>[
      const PlaceSuggestion(
        placeId: 'stale-place',
        placeResourceName: 'places/stale-place',
        fullText: StructuredText(text: 'Stale result'),
        primaryText: StructuredText(text: 'Stale result'),
        secondaryText: StructuredText(text: 'Old client'),
      ),
    ]);
    await tester.pump();

    expect(find.text('Stale result'), findsNothing);
  });

  testWidgets(
    'shows selection loading and prevents duplicate details requests',
    (tester) async {
      final backend = _SlowDetailsBackend();
      final client = PlacesClient.testing(apiKey: 'test', backend: backend);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              client: client,
              fetchPlaceDetailsOnSelection: true,
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Coffee Lab'));
      await tester.pump();
      await tester.tap(find.byType(TextField));
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(backend.fetchPlaceCount, 1);

      backend.completer.complete(
        const PlaceData(
          id: 'place-1',
          displayName: LocalizedText(text: 'Coffee Lab'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LinearProgressIndicator), findsNothing);
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

  testWidgets('form reset restores initial selection and calls onReset', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    final controller = PlacesAutocompleteController();
    var resetCount = 0;
    final selection = PlaceSelection(
      suggestion: const PlaceSuggestion(
        placeId: 'initial-place',
        placeResourceName: 'places/initial-place',
        fullText: StructuredText(text: 'Initial Place'),
        primaryText: StructuredText(text: 'Initial Place'),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            key: formKey,
            child: PlacesAutocompleteFormField(
              client: PlacesClient.testing(
                apiKey: 'test',
                backend: _FakeBackend(),
              ),
              controller: controller,
              initialValue: selection,
              onReset: () => resetCount++,
            ),
          ),
        ),
      ),
    );
    // External controllers are synchronized after the current build so a
    // shared controller cannot notify another field while widgets mount.
    await tester.pump();

    expect(controller.textController.text, 'Initial Place');
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pump();
    expect(controller.textController.text, isEmpty);

    formKey.currentState!.reset();
    await tester.pump();

    expect(controller.textController.text, 'Initial Place');
    expect(controller.selectedSelection, same(selection));
    expect(resetCount, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'switching a shared controller from field to form is build-safe',
    (tester) async {
      final controller = PlacesAutocompleteController(initialText: 'draft');
      final client = PlacesClient.testing(
        apiKey: 'test',
        backend: _FakeBackend(),
      );
      var showForm = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: ListView(
                children: <Widget>[
                  TextButton(
                    onPressed: () => setState(() => showForm = true),
                    child: const Text('Show form'),
                  ),
                  if (!showForm) ...<Widget>[
                    const Text('Regular field'),
                    const SizedBox(height: 8),
                    PlacesAutocompleteField(
                      client: client,
                      controller: controller,
                    ),
                  ],
                  if (showForm) ...<Widget>[
                    const Text('Form field'),
                    PlacesAutocompleteFormField(
                      client: client,
                      controller: controller,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show form'));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PlacesAutocompleteFormField), findsOneWidget);
      expect(controller.textController.text, isEmpty);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await client.close();
    },
  );

  testWidgets('form exposes forceErrorText, errorBuilder, and enabled', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteFormField(
            client: PlacesClient.testing(
              apiKey: 'test',
              backend: _FakeBackend(),
            ),
            enabled: false,
            forceErrorText: 'required place',
            errorBuilder: (context, errorText) => Text('custom: $errorText'),
            restorationId: 'place-field',
          ),
        ),
      ),
    );

    expect(find.text('custom: required place'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
  });

  testWidgets(
    'error state exposes a localized retry action',
    (tester) async {
      final backend = _RetryBackend();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlacesAutocompleteField(
              client: PlacesClient.testing(apiKey: 'test', backend: backend),
              strings: const PlacesStrings(retryText: 'Try again'),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'coffee');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(backend.attempts, 1);
      backend.failFirstAttempt();
      await tester.pump();
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(backend.attempts, 2);
      expect(find.text('Coffee Lab'), findsOneWidget);
    },
    // Synthetic Future errors are reported as uncaught by the browser test
    // harness before the widget consumes them. The real Chrome UI path is
    // covered by the remaining field tests; retry behavior is covered on VM.
    skip: kIsWeb,
  );

  testWidgets('dialog and Google attribution use localized semantics', (
    tester,
  ) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => PlacesAutocompleteOverlay.show(
              context,
              client: client,
              strings: const PlacesStrings(
                closeLabel: 'Dismiss places',
                poweredByGoogleLabel: 'Google attribution localized',
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss places'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Google attribution localized'),
      findsOneWidget,
    );
  });
}
