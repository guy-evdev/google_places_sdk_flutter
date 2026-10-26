// The controller used on its own, with no widget: the custom-UI path. Each
// test drives it the way such a UI does and checks the requests it sends —
// above all that every billing session ends exactly as Google prices it.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:material_ui/material_ui.dart';

const _place = PlaceSuggestion(
  placeId: 'place-1',
  placeResourceName: 'places/place-1',
  fullText: StructuredText(text: 'Coffee Lab, Main Street'),
  primaryText: StructuredText(text: 'Coffee Lab'),
  secondaryText: StructuredText(text: 'Main Street'),
);

const _query = QuerySuggestion(
  fullText: StructuredText(text: 'coffee near me'),
);

/// Records every request. A test can hold the next autocomplete or details
/// response open with [holdAutocomplete] / [holdDetails].
class _Backend implements PlacesBackend {
  final List<AutocompleteRequest> autocompleteRequests =
      <AutocompleteRequest>[];
  final List<PlaceDetailsRequest> detailsRequests = <PlaceDetailsRequest>[];
  final List<AutocompleteSessionToken> endedSessions =
      <AutocompleteSessionToken>[];
  Completer<List<AutocompleteSuggestion>>? holdAutocomplete;
  Completer<PlaceData>? holdDetails;
  Object? autocompleteError;
  Object? detailsError;
  bool closed = false;

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => (await autocompleteSuggestions(
    request,
  )).whereType<PlaceSuggestion>().toList();

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    autocompleteRequests.add(request);
    final hold = holdAutocomplete;
    if (hold != null) {
      holdAutocomplete = null;
      return hold.future;
    }
    if (autocompleteError case final error?) {
      throw error;
    }
    return const <AutocompleteSuggestion>[_place, _query];
  }

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    detailsRequests.add(request);
    final hold = holdDetails;
    if (hold != null) {
      holdDetails = null;
      return hold.future;
    }
    if (detailsError case final error?) {
      throw error;
    }
    return PlaceData(id: request.placeId, formattedAddress: 'Main Street');
  }

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {
    endedSessions.add(token);
  }

  @override
  Future<void> close() async => closed = true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A controller on [backend], and its teardown.
PlacesAutocompleteController _controller(
  _Backend backend, {
  PlacesAutocompleteOptions options = const PlacesAutocompleteOptions(),
}) {
  final controller = PlacesAutocompleteController(
    client: PlacesClient.testing(apiKey: 'test', backend: backend),
    options: options,
  );
  addTearDown(controller.dispose);
  return controller;
}

/// Types [text] the way a custom field's `onChanged` would.
void _type(PlacesAutocompleteController controller, String text) {
  controller.textController.text = text;
  controller.search();
}

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(milliseconds: 350));

void main() {
  testWidgets('search sends one request with the options, after the wait', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(
        languageCode: 'fr',
        includedPrimaryTypes: <String>['cafe'],
        includeQueryPredictions: true,
      ),
    );
    var notifications = 0;
    controller.addListener(() => notifications++);

    _type(controller, 'co');
    _type(controller, 'cof');
    expect(controller.status, PlacesSuggestionsStatus.loading);
    await tester.pump(const Duration(milliseconds: 200));
    expect(backend.autocompleteRequests, isEmpty);
    await _settle(tester);

    final request = backend.autocompleteRequests.single;
    expect(request.input, 'cof');
    expect(request.languageCode, 'fr');
    expect(request.includedPrimaryTypes, <String>['cafe']);
    expect(request.sessionToken, controller.sessionToken);
    expect(controller.status, PlacesSuggestionsStatus.results);
    expect(controller.suggestions, <AutocompleteSuggestion>[_place, _query]);
    expect(controller.highlightIndex, 0);
    expect(notifications, greaterThan(0));
  });

  testWidgets('maxSuggestions limits the suggestions', (tester) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(
        includeQueryPredictions: true,
        maxSuggestions: 1,
      ),
    );

    _type(controller, 'cof');
    await _settle(tester);

    expect(controller.suggestions, <AutocompleteSuggestion>[_place]);
  });

  testWidgets('short text sends nothing and keeps the session; empty text '
      'ends it', (tester) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(minInputLength: 3),
    );

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    _type(controller, 'co');
    await _settle(tester);
    expect(backend.autocompleteRequests, hasLength(1));
    expect(controller.status, isNull);
    expect(controller.sessionToken, session);
    expect(backend.endedSessions, isEmpty);

    _type(controller, '');
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    expect(controller.sessionToken, isNot(session));
  });

  testWidgets('select ends the session with the details request', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(backend);

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    final selection = await controller.select(_place);

    final details = backend.detailsRequests.single;
    expect(details.placeId, 'place-1');
    expect(details.sessionToken, session);
    expect(backend.autocompleteRequests.single.sessionToken, session);
    expect(details.fields, PlaceFieldPresets.address);
    expect(selection?.place?.formattedAddress, 'Main Street');
    expect(controller.selectedSelection, same(selection));
    expect(controller.textController.text, 'Coffee Lab, Main Street');
    expect(controller.status, isNull);
    expect(controller.selectionLoading, isFalse);
    // Ended once, by the details request; the next search is a new session.
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    expect(controller.sessionToken, isNot(session));
  });

  testWidgets('select without details still ends the session', (tester) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(
        fetchPlaceDetailsOnSelection: false,
      ),
    );

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    final selection = await controller.select(_place);

    expect(backend.detailsRequests, isEmpty);
    expect(selection?.suggestion, _place);
    expect(selection?.place, isNull);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
  });

  testWidgets('a failed pick completes with the error and ends the session', (
    tester,
  ) async {
    final backend = _Backend()
      ..detailsError = const PlacesException.validation(
        'bad',
        operation: PlacesOperation.placeDetails,
      );
    final controller = _controller(backend);

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;

    await expectLater(
      controller.select(_place),
      throwsA(isA<PlacesException>()),
    );
    expect(controller.selectionLoading, isFalse);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
  });

  testWidgets('clear ends the session and sends nothing', (tester) async {
    final backend = _Backend();
    final controller = _controller(backend);

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    controller.clear();

    expect(controller.textController.text, isEmpty);
    expect(controller.suggestions, isEmpty);
    expect(controller.status, isNull);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    expect(backend.detailsRequests, isEmpty);
  });

  testWidgets('resetSession abandons the search: ended, closed, no request', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(backend);

    _type(controller, 'cof');
    final session = controller.sessionToken;
    controller.resetSession();
    await _settle(tester);

    expect(backend.autocompleteRequests, isEmpty);
    expect(controller.status, isNull);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
  });

  testWidgets('a response for replaced text is dropped', (tester) async {
    final backend = _Backend();
    final controller = _controller(backend);
    final stale = Completer<List<AutocompleteSuggestion>>();
    backend.holdAutocomplete = stale;

    _type(controller, 'cof');
    await _settle(tester);
    _type(controller, 'tea');
    stale.complete(const <AutocompleteSuggestion>[_place]);
    await tester.pump();
    expect(controller.suggestions, isEmpty);
    expect(controller.status, PlacesSuggestionsStatus.loading);

    await _settle(tester);
    expect(backend.autocompleteRequests.last.input, 'tea');
    expect(controller.status, PlacesSuggestionsStatus.results);
  });

  testWidgets('a pick abandoned while loading completes with null', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(backend);
    final details = Completer<PlaceData>();
    backend.holdDetails = details;

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    final pick = controller.select(_place);
    await tester.pump();
    expect(controller.selectionLoading, isTrue);

    controller.resetSession();
    details.complete(const PlaceData(id: 'place-1'));

    expect(await pick, isNull);
    expect(controller.selectedPlace, isNull);
    expect(controller.selectionLoading, isFalse);
    // Ended once, by the reset — not again when the details arrive.
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
  });

  testWidgets('retry searches again after an error', (tester) async {
    final backend = _Backend()
      ..autocompleteError = const PlacesException.validation(
        'bad',
        operation: PlacesOperation.autocomplete,
      );
    final controller = _controller(backend);

    _type(controller, 'cof');
    await _settle(tester);
    expect(controller.status, PlacesSuggestionsStatus.error);
    expect(controller.error?.kind, PlacesErrorKind.validation);

    backend.autocompleteError = null;
    controller.retry();
    await tester.pump();
    expect(backend.autocompleteRequests, hasLength(2));
    expect(controller.status, PlacesSuggestionsStatus.results);
    expect(controller.error, isNull);
  });

  testWidgets('a query pick fills the text and ends the session; search() '
      'then searches for it', (tester) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(includeQueryPredictions: true),
    );

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    expect(await controller.select(_query), isNull);
    expect(controller.textController.text, 'coffee near me');
    expect(controller.status, isNull);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);

    controller.search();
    await _settle(tester);
    expect(backend.autocompleteRequests.last.input, 'coffee near me');
    expect(backend.autocompleteRequests.last.sessionToken, isNot(session));
  });

  testWidgets('moveHighlight wraps', (tester) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(includeQueryPredictions: true),
    );

    _type(controller, 'cof');
    await _settle(tester);
    controller.moveHighlight(-1);
    expect(controller.highlightIndex, 1);
    controller.moveHighlight(1);
    expect(controller.highlightIndex, 0);
  });

  testWidgets('changing options ends the session', (tester) async {
    final backend = _Backend();
    final controller = _controller(backend);

    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    controller.options = const PlacesAutocompleteOptions();
    expect(controller.sessionToken, session);

    controller.options = const PlacesAutocompleteOptions(languageCode: 'de');
    expect(controller.sessionToken, isNot(session));
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    expect(controller.status, isNull);
  });

  testWidgets('dispose ends the session and cancels a pending search', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = PlacesAutocompleteController(
      client: PlacesClient.testing(apiKey: 'test', backend: backend),
    );

    _type(controller, 'cof');
    final session = controller.sessionToken;
    controller.dispose();
    await _settle(tester);

    expect(backend.autocompleteRequests, isEmpty);
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    // The client was the caller's.
    expect(backend.closed, isFalse);
  });

  test('options compare by value', () {
    PlacesAutocompleteOptions options({int max = 5}) =>
        PlacesAutocompleteOptions(
          languageCode: 'fr',
          locationBias: LocationBias.circle(
            center: const PlaceCoordinates(latitude: 1, longitude: 2),
            radiusMeters: 5,
          ),
          includedPrimaryTypes: <String>['cafe'],
          selectionFields: <PlaceField>{PlaceField.id, PlaceField.location},
          selectionTimeZoneAt: DateTime(2026),
          maxSuggestions: max,
        );

    expect(options(), options());
    expect(options().hashCode, options().hashCode);
    expect(options(), isNot(options(max: 3)));
    expect(options(), isNot(const PlacesAutocompleteOptions()));
  });

  test('options differing in one search setting are not equal', () {
    const point = PlaceCoordinates(latitude: 1, longitude: 2);
    final variants = <PlacesAutocompleteOptions>[
      const PlacesAutocompleteOptions(languageCode: 'fr'),
      const PlacesAutocompleteOptions(regionCode: 'fr'),
      const PlacesAutocompleteOptions(origin: point),
      PlacesAutocompleteOptions(
        locationBias: LocationBias.circle(center: point, radiusMeters: 5),
      ),
      PlacesAutocompleteOptions(
        locationRestriction: LocationRestriction.rectangle(
          low: const PlaceCoordinates(latitude: 0, longitude: 0),
          high: point,
        ),
      ),
      const PlacesAutocompleteOptions(includedPrimaryTypes: <String>['cafe']),
      const PlacesAutocompleteOptions(includedRegionCodes: <String>['fr']),
      const PlacesAutocompleteOptions(includePureServiceAreaBusinesses: true),
      const PlacesAutocompleteOptions(includeFutureOpeningBusinesses: true),
      const PlacesAutocompleteOptions(includeQueryPredictions: true),
    ];
    for (final variant in variants) {
      expect(variant, isNot(const PlacesAutocompleteOptions()));
    }
  });

  test('with no client, search and select fail clearly', () {
    final controller = PlacesAutocompleteController(initialText: 'cof');
    addTearDown(controller.dispose);

    expect(controller.search, throwsStateError);
    expect(controller.retry, throwsStateError);
    expect(() => controller.select(_place), throwsStateError);
  });

  test('your own text controller and focus node are not disposed', () {
    final text = TextEditingController(text: 'cof');
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);

    final controller = PlacesAutocompleteController(
      textController: text,
      focusNode: focus,
    );
    expect(controller.textController, same(text));
    expect(controller.focusNode, same(focus));
    controller.dispose();

    expect(() => text.addListener(() {}), returnsNormally);
    expect(() => focus.addListener(() {}), returnsNormally);
  });

  testWidgets("a widget's parameters and client win over the controller's", (
    tester,
  ) async {
    final own = _Backend();
    final widgetBackend = _Backend();
    final controller = PlacesAutocompleteController(
      client: PlacesClient.testing(apiKey: 'own', backend: own),
      options: const PlacesAutocompleteOptions(languageCode: 'fr'),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(
            client: PlacesClient.testing(apiKey: 'w', backend: widgetBackend),
            controller: controller,
            languageCode: 'de',
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await _settle(tester);
    expect(widgetBackend.autocompleteRequests.single.languageCode, 'de');
    expect(own.autocompleteRequests, isEmpty);

    // Once no widget uses it, the controller's own apply again.
    await tester.pumpWidget(const SizedBox());
    _type(controller, 'tea');
    await _settle(tester);
    expect(own.autocompleteRequests.single.languageCode, 'fr');
    expect(widgetBackend.autocompleteRequests, hasLength(1));
  });

  // The recipe for searching again with a picked query suggestion.
  for (final mode in <String>['inline', 'form', 'dialog', 'fullscreen']) {
    testWidgets('$mode: onQuerySelection can search for the query', (
      tester,
    ) async {
      final backend = _Backend();
      final client = PlacesClient.testing(apiKey: 'test', backend: backend);
      final controller = PlacesAutocompleteController();
      addTearDown(controller.dispose);
      void searchAgain(QuerySuggestion _) => controller.search();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => switch (mode) {
                'inline' => PlacesAutocompleteField(
                  client: client,
                  controller: controller,
                  includeQueryPredictions: true,
                  onQuerySelection: searchAgain,
                ),
                'form' => PlacesAutocompleteFormField(
                  client: client,
                  controller: controller,
                  includeQueryPredictions: true,
                  onQuerySelection: searchAgain,
                ),
                _ => TextButton(
                  onPressed: () => PlacesAutocompleteOverlay.show(
                    context,
                    client: client,
                    controller: controller,
                    mode: mode == 'dialog'
                        ? PlacesAutocompleteOverlayMode.dialog
                        : PlacesAutocompleteOverlayMode.fullscreen,
                    includeQueryPredictions: true,
                    onQuerySelection: searchAgain,
                  ),
                  child: const Text('Search'),
                ),
              },
            ),
          ),
        ),
      );
      if (mode == 'dialog' || mode == 'fullscreen') {
        await tester.tap(find.text('Search'));
        await tester.pumpAndSettle();
      }

      await tester.enterText(find.byType(TextField), 'cof');
      await _settle(tester);
      await tester.tap(find.text('coffee near me'));
      await _settle(tester);

      expect(backend.autocompleteRequests.last.input, 'coffee near me');
      expect(
        backend.autocompleteRequests.last.sessionToken,
        isNot(backend.autocompleteRequests.first.sessionToken),
      );
      expect(find.text('Coffee Lab'), findsOneWidget);
    });
  }

  testWidgets('retry does nothing for text below minInputLength', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(
      backend,
      options: const PlacesAutocompleteOptions(minInputLength: 3),
    );
    controller.textController.text = 'co';

    controller.retry();
    await _settle(tester);

    expect(backend.autocompleteRequests, isEmpty);
    expect(controller.status, isNull);
  });

  testWidgets('only search settings end the session when they change', (
    tester,
  ) async {
    final backend = _Backend();
    final controller = _controller(backend);
    _type(controller, 'cof');
    await _settle(tester);
    final session = controller.sessionToken;

    controller.options = PlacesAutocompleteOptions(
      maxSuggestions: 3,
      minInputLength: 2,
      selectionFields: PlaceFieldPresets.all,
      selectionTimeZoneAt: DateTime(2026),
    );
    expect(controller.sessionToken, session);
    expect(backend.endedSessions, isEmpty);

    controller.options = const PlacesAutocompleteOptions(regionCode: 'us');
    expect(controller.sessionToken, isNot(session));
  });

  // A parent that rebuilds the field whenever the controller notifies, passing
  // values that are equal but new each time, must not end its own search.
  testWidgets('a parent rebuilding on the controller keeps the search', (
    tester,
  ) async {
    final backend = _Backend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: <Widget>[
                Text('status: ${controller.status}'),
                PlacesAutocompleteField(
                  client: client,
                  controller: controller,
                  locationBias: LocationBias.circle(
                    center: const PlaceCoordinates(
                      latitude: 32.08,
                      longitude: 34.78,
                    ),
                    radiusMeters: 500,
                  ),
                  selectionTimeZoneAt: DateTime.now(),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'cof');
    await _settle(tester);
    await tester.pumpAndSettle();

    expect(backend.autocompleteRequests, hasLength(1));
    expect(find.text('Coffee Lab'), findsOneWidget);
    expect(
      find.text('status: PlacesSuggestionsStatus.results'),
      findsOneWidget,
    );
    expect(backend.endedSessions, isEmpty);
  });

  testWidgets('a widget ending the session tells listeners after the frame', (
    tester,
  ) async {
    final backend = _Backend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    addTearDown(controller.dispose);
    Widget field(String language) => MaterialApp(
      home: Scaffold(
        body: PlacesAutocompleteField(
          client: client,
          controller: controller,
          languageCode: language,
        ),
      ),
    );
    await tester.pumpWidget(field('en'));
    await tester.enterText(find.byType(TextField), 'cof');
    await _settle(tester);
    expect(controller.status, PlacesSuggestionsStatus.results);
    var notifications = 0;
    controller.addListener(() => notifications++);

    await tester.pumpWidget(field('de'));
    expect(controller.status, isNull);
    expect(backend.endedSessions, hasLength(1));
    expect(notifications, 1);
  });

  // Moving a controller to another widget builds the new widget before the old
  // one is disposed; a pick loading in the old one must not leave the new one
  // stuck.
  testWidgets('a controller moved to another widget mid-pick recovers', (
    tester,
  ) async {
    final backend = _Backend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final controller = PlacesAutocompleteController();
    addTearDown(controller.dispose);
    Widget layout({required bool row}) {
      final field = PlacesAutocompleteField(
        client: client,
        controller: controller,
      );
      return MaterialApp(
        home: Scaffold(
          body: row
              ? Row(children: <Widget>[Expanded(child: field)])
              : Column(children: <Widget>[field]),
        ),
      );
    }

    await tester.pumpWidget(layout(row: false));
    await tester.enterText(find.byType(TextField), 'cof');
    await _settle(tester);
    final session = controller.sessionToken;
    final details = Completer<PlaceData>();
    backend.holdDetails = details;
    await tester.tap(find.text('Coffee Lab'));
    await tester.pump();
    expect(controller.selectionLoading, isTrue);

    await tester.pumpWidget(layout(row: true));
    details.complete(const PlaceData(id: 'place-1'));
    await tester.pumpAndSettle();

    expect(controller.selectionLoading, isFalse);
    expect(controller.sessionToken, isNot(session));
    expect(backend.endedSessions, <AutocompleteSessionToken>[session]);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);

    // The new widget searches and picks as usual.
    await tester.enterText(find.byType(TextField), 'tea');
    await _settle(tester);
    await tester.tap(find.text('Coffee Lab'));
    await tester.pumpAndSettle();
    expect(controller.selectedPlace?.id, 'place-1');
  });
}
