// The apiKey: path builds a real PlacesClient, which uses a REST backend on
// the VM and the Maps JavaScript backend on web. These tests observe the REST
// backend's HTTP traffic, so they run on the VM only. The widget code under
// test is the same on both platforms.
@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

/// Stands in for every `http.Client()` the package creates, so a test can see
/// which key each widget-owned client sends and whether it was closed.
class _RecordingHttpClient extends http.BaseClient {
  final List<http.BaseRequest> requests = <http.BaseRequest>[];
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final body = request.url.path.endsWith(':autocomplete')
        ? <String, Object?>{
            'suggestions': <Object?>[
              <String, Object?>{
                'placePrediction': <String, Object?>{
                  'placeId': 'place-1',
                  'place': 'places/place-1',
                  'text': <String, Object?>{'text': 'Coffee Lab'},
                },
              },
            ],
          }
        : <String, Object?>{'id': 'place-1', 'formattedAddress': 'Main St'};
    return http.StreamedResponse(
      Stream<List<int>>.value(utf8.encode(jsonEncode(body))),
      200,
      headers: const <String, String>{'content-type': 'application/json'},
    );
  }

  @override
  void close() => closed = true;
}

class _ClosingBackend implements PlacesBackend {
  bool closed = false;

  @override
  Future<void> close() async => closed = true;

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Runs [body] with every package-created HTTP client recorded in [clients].
Future<void> _withRecordedClients(
  List<_RecordingHttpClient> clients,
  Future<void> Function() body,
) => http.runWithClient(body, () {
  final client = _RecordingHttpClient();
  clients.add(client);
  return client;
});

String? _keyOf(http.BaseRequest request) => request.headers['x-goog-api-key'];

Future<void> _search(
  WidgetTester tester,
  Finder scope, {
  String query = 'cof',
}) async {
  await tester.enterText(
    find.descendant(of: scope, matching: find.byType(TextField)),
    query,
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the field creates one client per key and closes it', (
    tester,
  ) async {
    final clients = <_RecordingHttpClient>[];
    await _withRecordedClients(clients, () async {
      Widget field(String apiKey) => MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(apiKey: apiKey)),
      );

      await tester.pumpWidget(field('key-1'));
      await _search(tester, find.byType(PlacesAutocompleteField));
      await tester.pumpWidget(field('key-1'));
      expect(clients, hasLength(1), reason: 'a rebuild keeps the client');
      expect(_keyOf(clients.single.requests.single), 'key-1');

      await tester.pumpWidget(field('key-2'));
      expect(clients, hasLength(2));
      expect(clients.first.closed, isTrue);
      await _search(
        tester,
        find.byType(PlacesAutocompleteField),
        query: 'coffee',
      );
      expect(_keyOf(clients.last.requests.single), 'key-2');

      await tester.pumpWidget(const SizedBox());
      expect(clients.last.closed, isTrue);
    });
  });

  testWidgets('the field never closes a client it was given', (tester) async {
    final backend = _ClosingBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );
    await tester.pumpWidget(const SizedBox());

    expect(backend.closed, isFalse);
  });

  testWidgets('switching between client and apiKey closes only owned ones', (
    tester,
  ) async {
    final backend = _ClosingBackend();
    final external = PlacesClient.testing(apiKey: 'test', backend: backend);
    final clients = <_RecordingHttpClient>[];
    await _withRecordedClients(clients, () async {
      Widget field({PlacesClient? client, String? apiKey}) => MaterialApp(
        home: Scaffold(
          body: PlacesAutocompleteField(client: client, apiKey: apiKey),
        ),
      );

      await tester.pumpWidget(field(client: external));
      expect(clients, isEmpty);

      await tester.pumpWidget(field(apiKey: 'key-1'));
      expect(backend.closed, isFalse, reason: 'the caller owns its client');
      expect(clients, hasLength(1));

      await tester.pumpWidget(field(client: external));
      expect(clients.single.closed, isTrue);
      expect(backend.closed, isFalse);
    });
  });

  group('apiKey reaches every field mode', () {
    for (final fieldMode in PlacesAutocompleteFieldMode.values) {
      testWidgets(fieldMode.name, (tester) async {
        final clients = <_RecordingHttpClient>[];
        await _withRecordedClients(clients, () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PlacesAutocompleteField(
                  apiKey: 'key-1',
                  fieldMode: fieldMode,
                ),
              ),
            ),
          );
          var scope = find.byType(PlacesAutocompleteField);
          if (fieldMode != PlacesAutocompleteFieldMode.inline) {
            await tester.tap(find.byType(TextField));
            await tester.pumpAndSettle();
            scope = find.byType(PlacesAutocompleteOverlay);
          }
          await _search(tester, scope);
          await tester.tap(find.text('Coffee Lab'));
          await tester.pumpAndSettle();

          final requests = clients.expand((client) => client.requests);
          expect(requests, isNotEmpty);
          expect(requests.map(_keyOf), everyElement('key-1'));
          final searching = clients.where((c) => c.requests.isNotEmpty).single;
          // Inline, the field's own client stays open. A launcher's overlay
          // owns its client, so it is closed as soon as the overlay is.
          expect(
            searching.closed,
            fieldMode != PlacesAutocompleteFieldMode.inline,
          );

          await tester.pumpWidget(const SizedBox());
          expect(clients.every((client) => client.closed), isTrue);
        });
      });
    }
  });

  for (final mode in PlacesAutocompleteOverlayMode.values) {
    testWidgets('show(apiKey:) in ${mode.name} mode closes its client', (
      tester,
    ) async {
      final clients = <_RecordingHttpClient>[];
      await _withRecordedClients(clients, () async {
        Future<PlaceSelection?>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = PlacesAutocompleteOverlay.show(
                  context,
                  apiKey: 'key-1',
                  mode: mode,
                ),
                child: const Text('Pick'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        await _search(tester, find.byType(PlacesAutocompleteOverlay));
        await tester.tap(find.text('Coffee Lab'));
        await tester.pumpAndSettle();

        expect((await result)?.placeId, 'place-1');
        expect(clients, hasLength(1));
        expect(clients.single.requests.map(_keyOf), everyElement('key-1'));
        expect(clients.single.closed, isTrue);
      });
    });
  }

  testWidgets('the form field accepts apiKey', (tester) async {
    final clients = <_RecordingHttpClient>[];
    await _withRecordedClients(clients, () async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(child: PlacesAutocompleteFormField(apiKey: 'key-1')),
          ),
        ),
      );
      await _search(tester, find.byType(PlacesAutocompleteFormField));

      expect(_keyOf(clients.single.requests.single), 'key-1');
    });
  });

  group('default selection requests exactly the Essentials address mask', () {
    // Literal field names, not PlaceFieldPresets.address: editing the preset
    // must fail this test rather than silently move every user's selections
    // to a pricier tier. All five are Place Details Essentials (`id` alone is
    // Essentials IDs Only), so the request bills as Essentials.
    const essentialsAddressMask = <String>{
      'id',
      'formattedAddress',
      'shortFormattedAddress',
      'location',
      'addressComponents',
    };

    Set<String> detailsMaskOf(List<_RecordingHttpClient> clients) {
      final details = clients
          .expand((client) => client.requests)
          .where((request) => request.url.path.endsWith('places/place-1'))
          .single;
      return details.headers['x-goog-fieldmask']!.split(',').toSet();
    }

    for (final fieldMode in PlacesAutocompleteFieldMode.values) {
      testWidgets('field, ${fieldMode.name} mode', (tester) async {
        final clients = <_RecordingHttpClient>[];
        await _withRecordedClients(clients, () async {
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: PlacesAutocompleteField(
                  apiKey: 'key-1',
                  fieldMode: fieldMode,
                ),
              ),
            ),
          );
          var scope = find.byType(PlacesAutocompleteField);
          if (fieldMode != PlacesAutocompleteFieldMode.inline) {
            await tester.tap(find.byType(TextField));
            await tester.pumpAndSettle();
            scope = find.byType(PlacesAutocompleteOverlay);
          }
          await _search(tester, scope);
          await tester.tap(find.text('Coffee Lab'));
          await tester.pumpAndSettle();

          expect(detailsMaskOf(clients), essentialsAddressMask);
        });
      });
    }

    testWidgets('form field', (tester) async {
      final clients = <_RecordingHttpClient>[];
      await _withRecordedClients(clients, () async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Form(child: PlacesAutocompleteFormField(apiKey: 'key-1')),
            ),
          ),
        );
        await _search(tester, find.byType(PlacesAutocompleteFormField));
        await tester.tap(find.text('Coffee Lab'));
        await tester.pumpAndSettle();

        expect(detailsMaskOf(clients), essentialsAddressMask);
      });
    });

    testWidgets('show()', (tester) async {
      final clients = <_RecordingHttpClient>[];
      await _withRecordedClients(clients, () async {
        Future<PlaceSelection?>? result;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => TextButton(
                onPressed: () => result = PlacesAutocompleteOverlay.show(
                  context,
                  apiKey: 'key-1',
                ),
                child: const Text('Pick'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Pick'));
        await tester.pumpAndSettle();
        await _search(tester, find.byType(PlacesAutocompleteOverlay));
        await tester.tap(find.text('Coffee Lab'));
        await tester.pumpAndSettle();

        expect((await result)?.place?.formattedAddress, 'Main St');
        expect(detailsMaskOf(clients), essentialsAddressMask);
      });
    });
  });

  group('exactly one of client and apiKey', () {
    final client = PlacesClient.testing(
      apiKey: 'test',
      backend: _ClosingBackend(),
    );

    test('field', () {
      expect(PlacesAutocompleteField.new, throwsAssertionError);
      expect(
        () => PlacesAutocompleteField(client: client, apiKey: 'key'),
        throwsAssertionError,
      );
    });

    test('form field', () {
      expect(PlacesAutocompleteFormField.new, throwsAssertionError);
      expect(
        () => PlacesAutocompleteFormField(client: client, apiKey: 'key'),
        throwsAssertionError,
      );
    });

    test('overlay', () {
      final controller = PlacesAutocompleteController();
      addTearDown(controller.dispose);
      expect(
        () => PlacesAutocompleteOverlay(
          controller: controller,
          mode: PlacesAutocompleteOverlayMode.dialog,
        ),
        throwsAssertionError,
      );
    });

    testWidgets('show()', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      // show() is async, so the assertion arrives through its future.
      await expectLater(
        PlacesAutocompleteOverlay.show(context),
        throwsAssertionError,
      );
      await expectLater(
        PlacesAutocompleteOverlay.show(context, client: client, apiKey: 'key'),
        throwsAssertionError,
      );
    });
  });
}
