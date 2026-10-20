import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:material_ui/material_ui.dart';

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

class _DistanceBackend extends _FakeBackend {
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
        // Google only populates this when the request carries an origin.
        distanceMeters: request.origin == null ? null : 1234,
      ),
    ];
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

  group('field options reach every field mode', () {
    // Standing rule from the 0.6.1 audit: dialog and fullscreen used to
    // silently drop decoration, suggestionBuilder, showPoweredByGoogle,
    // onClearField, and enabled, because _openOverlay never forwarded them and
    // PlacesAutocompleteOverlay never declared them. Every option added to
    // PlacesAutocompleteField must be proven to reach all three modes.
    // In launcher modes the read-only launcher field stays mounted behind the
    // overlay, so assertions must be scoped to the overlay itself. Otherwise a
    // test would pass on the launcher's copy of the option and prove nothing.
    Finder scopeFor(PlacesAutocompleteFieldMode fieldMode) =>
        fieldMode == PlacesAutocompleteFieldMode.inline
        ? find.byType(PlacesAutocompleteField)
        : find.byType(PlacesAutocompleteOverlay);

    Finder within(PlacesAutocompleteFieldMode fieldMode, Finder matching) =>
        find.descendant(of: scopeFor(fieldMode), matching: matching);

    Future<void> openMode(
      WidgetTester tester,
      PlacesAutocompleteFieldMode fieldMode,
      Widget field,
    ) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: field)));
      if (fieldMode != PlacesAutocompleteFieldMode.inline) {
        await tester.tap(find.byType(TextField));
        await tester.pumpAndSettle();
      }
    }

    Future<void> search(
      WidgetTester tester,
      PlacesAutocompleteFieldMode fieldMode,
    ) async {
      await tester.enterText(within(fieldMode, find.byType(TextField)), 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
    }

    for (final fieldMode in PlacesAutocompleteFieldMode.values) {
      testWidgets('${fieldMode.name} honours decoration', (tester) async {
        final client = PlacesClient.testing(
          apiKey: 'test',
          backend: _FakeBackend(),
        );

        await openMode(
          tester,
          fieldMode,
          PlacesAutocompleteField(
            client: client,
            fieldMode: fieldMode,
            decoration: const InputDecoration(labelText: 'Delivery address'),
          ),
        );

        expect(
          within(fieldMode, find.text('Delivery address')),
          findsOneWidget,
        );
      });

      testWidgets('${fieldMode.name} honours showPoweredByGoogle: false', (
        tester,
      ) async {
        final client = PlacesClient.testing(
          apiKey: 'test',
          backend: _FakeBackend(),
        );

        await openMode(
          tester,
          fieldMode,
          PlacesAutocompleteField(
            client: client,
            fieldMode: fieldMode,
            showPoweredByGoogle: false,
          ),
        );
        await search(tester, fieldMode);

        expect(within(fieldMode, find.text('Coffee Lab')), findsWidgets);
        expect(find.bySemanticsLabel('Powered by Google'), findsNothing);
      });

      testWidgets('${fieldMode.name} honours suggestionBuilder', (
        tester,
      ) async {
        final client = PlacesClient.testing(
          apiKey: 'test',
          backend: _FakeBackend(),
        );

        await openMode(
          tester,
          fieldMode,
          PlacesAutocompleteField(
            client: client,
            fieldMode: fieldMode,
            suggestionBuilder: (context, suggestion) =>
                Text('custom ${suggestion.placeId}'),
          ),
        );
        await search(tester, fieldMode);

        expect(within(fieldMode, find.text('custom place-1')), findsOneWidget);
      });

      testWidgets('${fieldMode.name} honours origin', (tester) async {
        final backend = _DistanceBackend();
        final client = PlacesClient.testing(apiKey: 'test', backend: backend);

        await openMode(
          tester,
          fieldMode,
          PlacesAutocompleteField(
            client: client,
            fieldMode: fieldMode,
            origin: const PlaceCoordinates(latitude: 40.7, longitude: -74.0),
            strings: const PlacesStrings(distanceUnitMeters: 'meters'),
          ),
        );
        await search(tester, fieldMode);

        expect(backend.lastAutocompleteRequest?.origin?.latitude, 40.7);
        expect(within(fieldMode, find.text('1234 meters')), findsOneWidget);
      });
    }
  });

  testWidgets('no origin means no distance is requested or rendered', (
    tester,
  ) async {
    final backend = _DistanceBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(backend.lastAutocompleteRequest?.origin, isNull);
    expect(find.textContaining('1234'), findsNothing);
  });

  group('dialog and fullscreen layouts', () {
    // A short phone screen with the keyboard up: the old fullscreen layout
    // overflowed here, and both modes scrolled the field away with the list.
    const screen = Size(400, 640);
    const keyboard = 300.0;

    Future<Finder> openAndSearch(
      WidgetTester tester,
      PlacesAutocompleteOverlayMode mode, {
      String? title,
      InputDecoration? decoration,
      ThemeData? theme,
      Size size = screen,
      double keyboardHeight = keyboard,
      ValueChanged<PlaceSelection?>? onResult,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
      addTearDown(tester.view.reset);
      final client = PlacesClient.testing(
        apiKey: 'test',
        backend: _FakeBackend(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                final result = await PlacesAutocompleteOverlay.show(
                  context,
                  client: client,
                  mode: mode,
                  title: title,
                  decoration: decoration,
                );
                onResult?.call(result);
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final field = find.descendant(
        of: find.byType(PlacesAutocompleteOverlay),
        matching: find.byType(TextField),
      );
      await tester.enterText(field, 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      return field;
    }

    for (final mode in PlacesAutocompleteOverlayMode.values) {
      testWidgets('${mode.name}: the field stays put while results scroll', (
        tester,
      ) async {
        final field = await openAndSearch(tester, mode);
        final fieldRect = tester.getRect(field);
        final results = tester.state<ScrollableState>(
          find.descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          ),
        );

        // Google's attribution is visible beside the results, above the
        // keyboard, before and after scrolling — never scrolled away.
        void expectAttributionVisible() => expect(
          tester.getRect(find.bySemanticsLabel('Powered by Google')).bottom,
          lessThanOrEqualTo(screen.height - keyboard),
        );
        expectAttributionVisible();

        await tester.drag(find.byType(ListView), const Offset(0, -200));
        await tester.pumpAndSettle();

        expect(results.position.pixels, greaterThan(0));
        expect(tester.getRect(field), fieldRect);
        expectAttributionVisible();
      });

      testWidgets('${mode.name}: result rows run edge to edge', (tester) async {
        await openAndSearch(tester, mode);
        final row = find.ancestor(
          of: find.text('Coffee Lab'),
          matching: find.byType(ListTile),
        );
        final overlay = tester.getRect(find.byType(PlacesAutocompleteOverlay));

        expect(tester.getRect(row).left, overlay.left);
        expect(tester.getRect(row).right, overlay.right);
      });
    }

    testWidgets('fullscreen puts the field in the top bar, with one dismiss '
        'control', (tester) async {
      final field = await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.fullscreen,
      );

      final back = tester.getRect(find.byTooltip('Close'));
      final fieldRect = tester.getRect(field);
      expect(fieldRect.top, lessThan(kToolbarHeight));
      expect(back.center.dy, moreOrLessEquals(fieldRect.center.dy, epsilon: 1));
      expect(back.right, lessThanOrEqualTo(fieldRect.left));
      expect(
        tester.getRect(find.text('Coffee Lab')).top,
        greaterThan(fieldRect.bottom),
      );
      expect(find.byTooltip('Close'), findsOneWidget);
      expect(find.byType(BackButtonIcon), findsOneWidget);
      // Borderless in the bar unless the decoration sets a border.
      expect(
        tester.widget<TextField>(field).decoration!.border,
        InputBorder.none,
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(PlacesAutocompleteOverlay), findsNothing);
    });

    testWidgets('fullscreen bar ignores a coloured appBarTheme', (
      tester,
    ) async {
      // The field's text is onSurface; on an app's brand-coloured bar it
      // would be unreadable.
      final theme = ThemeData(
        appBarTheme: const AppBarThemeData(
          backgroundColor: Color(0xFF3F51B5),
          foregroundColor: Color(0xFFFFFFFF),
        ),
      );
      final field = await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.fullscreen,
        theme: theme,
      );

      final bar = tester.widget<Material>(
        find.ancestor(of: field, matching: find.byType(Material)).first,
      );
      expect(bar.color, theme.colorScheme.surface);
    });

    testWidgets('fullscreen bar fits a labelled field and its error line', (
      tester,
    ) async {
      final field = await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.fullscreen,
        decoration: const InputDecoration(
          labelText: 'Address',
          errorText: 'Pick a place',
          border: OutlineInputBorder(),
        ),
      );

      final bar = tester.getRect(
        find.ancestor(of: field, matching: find.byType(Material)).first,
      );
      for (final text in <String>['Address', 'Pick a place']) {
        final rect = tester.getRect(find.text(text));
        expect(rect.top, greaterThanOrEqualTo(bar.top), reason: text);
        expect(rect.bottom, lessThanOrEqualTo(bar.bottom), reason: text);
      }
      expect(
        tester.getRect(find.text('Coffee Lab')).top,
        greaterThan(bar.bottom),
      );
      // A decoration that sets a border keeps it.
      expect(
        tester.widget<TextField>(field).decoration!.border,
        isA<OutlineInputBorder>(),
      );
    });

    testWidgets('Enter on the back button goes back; it does not select', (
      tester,
    ) async {
      PlaceSelection? result;
      var returned = false;
      await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.fullscreen,
        onResult: (value) {
          result = value;
          returned = true;
        },
      );
      // Back from the field: the back button comes before it. Leaving the
      // field closes the results, so Enter reaches the button.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(returned, isTrue);
      expect(result, isNull);
    });

    testWidgets('a dialog too short to pin its field scrolls as a whole', (
      tester,
    ) async {
      // A phone in landscape with the keyboard up.
      final field = await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.dialog,
        size: const Size(640, 360),
        keyboardHeight: 200,
      );

      expect(tester.takeException(), isNull);
      expect(tester.getRect(field).top, greaterThanOrEqualTo(0));
    });

    testWidgets('dialog draws the title', (tester) async {
      await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.dialog,
        title: 'Find a place',
      );
      expect(find.text('Find a place'), findsOneWidget);
    });

    testWidgets('fullscreen names the screen with the title instead', (
      tester,
    ) async {
      await openAndSearch(
        tester,
        PlacesAutocompleteOverlayMode.fullscreen,
        title: 'Find a place',
      );
      expect(find.text('Find a place'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Find a place')),
        isSemantics(label: 'Find a place', namesRoute: true),
      );
    });
  });

  group('inline suggestions float, anchored to the field', () {
    const screen = Size(400, 640);
    const keyboard = 300.0;

    PlacesClient fakeClient() =>
        PlacesClient.testing(apiKey: 'test', backend: _FakeBackend());

    Future<void> search(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField), 'cof');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    void useKeyboard(WidgetTester tester) {
      tester.view.physicalSize = screen;
      tester.view.devicePixelRatio = 1.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard);
      addTearDown(tester.view.reset);
    }

    Rect attributionRect(WidgetTester tester) =>
        tester.getRect(find.bySemanticsLabel('Powered by Google'));

    testWidgets('they cover the content below instead of pushing it down', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                PlacesAutocompleteField(client: fakeClient()),
                const Text('Below the field'),
              ],
            ),
          ),
        ),
      );
      final below = tester.getTopLeft(find.text('Below the field'));
      await search(tester);

      expect(tester.getTopLeft(find.text('Below the field')), below);
      final results = tester.getRect(find.byType(ListView));
      expect(
        results.top,
        greaterThan(tester.getRect(find.byType(TextField)).bottom),
      );
      expect(
        results.overlaps(tester.getRect(find.text('Below the field'))),
        isTrue,
        reason: 'drawn over the content below',
      );
    });

    testWidgets('they stay above the keyboard, and only they scroll', (
      tester,
    ) async {
      useKeyboard(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PlacesAutocompleteField(client: fakeClient())),
        ),
      );
      await search(tester);
      expect(attributionRect(tester).bottom, lessThanOrEqualTo(340));
      final results = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );

      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pumpAndSettle();

      expect(results.position.pixels, greaterThan(0));
      expect(attributionRect(tester).bottom, lessThanOrEqualTo(340));
    });

    testWidgets('they still show after the field visits a launcher mode', (
      tester,
    ) async {
      // A portal that unmounts loses its shown state for good, so the field
      // keeps one mounted in every mode.
      var mode = PlacesAutocompleteFieldMode.inline;
      late StateSetter setMode;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                setMode = setState;
                return PlacesAutocompleteField(
                  client: fakeClient(),
                  fieldMode: mode,
                );
              },
            ),
          ),
        ),
      );
      setMode(() => mode = PlacesAutocompleteFieldMode.dialog);
      await tester.pump();
      setMode(() => mode = PlacesAutocompleteFieldMode.inline);
      await tester.pump();

      await search(tester);
      expect(find.text('Coffee Lab'), findsOneWidget);
    });

    testWidgets("scrolling them is not scrolling the page", (tester) async {
      useKeyboard(tester);
      var pageNotifications = 0;
      late BuildContext pageContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Page')),
            body: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                pageNotifications++;
                return false;
              },
              child: Builder(
                builder: (context) {
                  pageContext = context;
                  return Column(
                    children: <Widget>[
                      PlacesAutocompleteField(client: fakeClient()),
                      Expanded(
                        child: ListView(
                          children: const <Widget>[Text('Page content')],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await search(tester);
      pageNotifications = 0;

      await tester.drag(
        find.descendant(
          of: find.byType(PlacesAutocompleteField),
          matching: find.byType(ListView),
        ),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      expect(pageNotifications, 0);
      // The page's own list is the only one on its PrimaryScrollController.
      expect(PrimaryScrollController.of(pageContext).positions, hasLength(1));
    });

    testWidgets('they open above a field the keyboard leaves no room under', (
      tester,
    ) async {
      useKeyboard(tester);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PlacesAutocompleteField(client: fakeClient()),
            ),
          ),
        ),
      );
      await search(tester);

      final fieldRect = tester.getRect(find.byType(TextField));
      expect(fieldRect.bottom, lessThanOrEqualTo(screen.height - keyboard));
      expect(attributionRect(tester).bottom, lessThanOrEqualTo(fieldRect.top));
      expect(
        tester.getRect(find.byType(ListView)).top,
        greaterThanOrEqualTo(0),
      );
    });
  });

  testWidgets('Escape closes the suggestion list', (tester) async {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _FakeBackend(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Coffee Lab'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.text('Coffee Lab'), findsNothing);
  });

  testWidgets('retry actually retries, including when it takes focus', (
    tester,
  ) async {
    // On web the retry TextButton takes focus from the field. That used to
    // trip the focus listener into treating the tap as session abandonment:
    // the search UI closed and no second request was ever issued, so Retry
    // silently did nothing in a browser. This test fails on the Chrome lane
    // without the pointer guard around the whole search surface.
    final backend = _RetryBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    backend.failFirstAttempt();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(backend.attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(backend.attempts, 2);
    expect(find.text('Coffee Lab'), findsOneWidget);
  });

  testWidgets('retry issues exactly one more request', (tester) async {
    // _retrySearch now cancels any pending debounce before searching. Typing
    // clears the error and hides the Retry button, so that guard is defensive
    // rather than a user-reachable double-billing path; what is reachable, and
    // what this pins, is that a retry never bills more than one extra call.
    final backend = _RetryBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    backend.failFirstAttempt();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(backend.attempts, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(backend.attempts, 2);

    // Nothing left pending may fire a third, billed request.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(backend.attempts, 2);
    expect(find.text('Coffee Lab'), findsOneWidget);
  });

  testWidgets('the field keeps focus and decoration while a selection loads', (
    tester,
  ) async {
    final backend = _SlowDetailsBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: client,
            fetchPlaceDetailsOnSelection: true,
            decoration: const InputDecoration(labelText: 'Pickup address'),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    // Previously enabled: false here, which dropped focus and flickered the
    // decoration into its disabled colours mid-selection.
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.text('Pickup address'), findsOneWidget);

    backend.completer.complete(const PlaceData(id: 'place-1'));
    await tester.pumpAndSettle();
  });
}
