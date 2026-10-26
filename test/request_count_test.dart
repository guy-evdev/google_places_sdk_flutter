// Every request a user's search costs, counted end to end through the widget:
// typing, a pick with its details request, a second search, and leaving the
// field. The backend records every call it receives, so an extra or missing
// request — or a session ended twice — fails the exact list below. Ending a
// session is the client's own bookkeeping, not a request to Google (a no-op
// over REST), but it is recorded too, because when it happens is the billing
// contract.
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

class _RecordingBackend implements PlacesBackend {
  final List<String> calls = <String>[];
  final List<AutocompleteRequest> autocompleteRequests =
      <AutocompleteRequest>[];
  final List<PlaceDetailsRequest> detailsRequests = <PlaceDetailsRequest>[];
  final List<AutocompleteSessionToken> endedSessions =
      <AutocompleteSessionToken>[];

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    calls.add('autocomplete ${request.input}');
    autocompleteRequests.add(request);
    return const <PlaceSuggestion>[_place];
  }

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    calls.add('fetchPlace ${request.placeId}');
    detailsRequests.add(request);
    return const PlaceData(id: 'place-1', formattedAddress: 'Main Street');
  }

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {
    calls.add('endAutocompleteSession');
    endedSessions.add(token);
  }

  @override
  Future<void> close() async {}

  // Any other operation is a request this flow must never send.
  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add('unexpected ${invocation.memberName}');
    return super.noSuchMethod(invocation);
  }
}

void main() {
  testWidgets('type, pick, search again, leave: every request counted', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    final client = PlacesClient.testing(apiKey: 'test', backend: backend);
    final field = find.byType(TextField);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PlacesAutocompleteField(client: client)),
      ),
    );

    // Three quick keystrokes, one pause: one request.
    await tester.enterText(field, 'c');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'co');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    expect(backend.calls, <String>['autocomplete cof']);

    // Waiting longer sends nothing more; the next pause sends one more.
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(field, 'coff');
    await tester.pump(const Duration(milliseconds: 350));
    expect(backend.calls, <String>['autocomplete cof', 'autocomplete coff']);

    // The pick: one details request in the same session, which ends it once.
    await tester.tap(find.text('Coffee Lab'));
    await tester.pumpAndSettle();
    final firstSession = backend.autocompleteRequests.first.sessionToken!;
    expect(backend.calls, <String>[
      'autocomplete cof',
      'autocomplete coff',
      'fetchPlace place-1',
      'endAutocompleteSession',
    ]);
    expect(backend.autocompleteRequests[1].sessionToken, firstSession);
    final details = backend.detailsRequests.single;
    expect(details.sessionToken, firstSession);
    expect(details.fields.map((field) => field.apiName).toSet(), <String>{
      'id',
      'formattedAddress',
      'shortFormattedAddress',
      'location',
      'addressComponents',
    });
    expect(backend.endedSessions, <AutocompleteSessionToken>[firstSession]);

    // A new search is a new session; leaving the field ends it, no request.
    await tester.enterText(field, 'tea');
    await tester.pump(const Duration(milliseconds: 350));
    final secondSession = backend.autocompleteRequests.last.sessionToken!;
    expect(secondSession, isNot(firstSession));
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();

    expect(backend.calls, <String>[
      'autocomplete cof',
      'autocomplete coff',
      'fetchPlace place-1',
      'endAutocompleteSession',
      'autocomplete tea',
      'endAutocompleteSession',
    ]);
    expect(backend.endedSessions, <AutocompleteSessionToken>[
      firstSession,
      secondSession,
    ]);

    // Removing the field sends no request; it ends its new, unused session.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    expect(backend.calls.skip(6), <String>['endAutocompleteSession']);
    expect(backend.endedSessions.last, isNot(firstSession));
    expect(backend.endedSessions.last, isNot(secondSession));
  });
}
