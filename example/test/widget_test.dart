import 'dart:async';

import 'package:example/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:material_ui/material_ui.dart';

class _RecordingBackend implements PlacesBackend {
  final List<TextSearchRequest> textSearchRequests = <TextSearchRequest>[];
  final List<TextSearchRequest> pagedSearchRequests = <TextSearchRequest>[];
  final List<PlacesCancellationToken?> cancellationTokens =
      <PlacesCancellationToken?>[];
  Completer<List<PlaceData>>? firstTextSearch;
  Object? textSearchError;
  int closeCount = 0;
  List<PlaceSuggestion> suggestions = const <PlaceSuggestion>[];
  PlaceData place = const PlaceData(id: 'place-1');
  final List<PlaceDetailsRequest> detailsRequests = <PlaceDetailsRequest>[];
  final List<PhotoMediaRequest> photoRequests = <PhotoMediaRequest>[];

  @override
  Future<List<PlaceSuggestion>> autocomplete(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => suggestions;

  @override
  Future<List<AutocompleteSuggestion>> autocompleteSuggestions(
    AutocompleteRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => suggestions;

  @override
  Future<void> close() async {
    closeCount++;
  }

  @override
  Future<void> endAutocompleteSession(AutocompleteSessionToken token) async {}

  @override
  Future<PlaceData> fetchPlace(
    PlaceDetailsRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    detailsRequests.add(request);
    return place;
  }

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    photoRequests.add(request);
    return const PlacePhotoMedia(
      name: 'places/place-1/photos/photo-1/media',
      photoUri: 'https://example.com/photo.jpg',
    );
  }

  @override
  Future<PlaceTimeZoneData> fetchTimeZone(
    TimeZoneRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => PlaceTimeZoneData(
    dstOffset: Duration.zero,
    rawOffset: Duration.zero,
    timeZoneId: 'UTC',
    timeZoneName: 'Coordinated Universal Time',
    timestamp: DateTime.utc(2026, 7, 20),
  );

  @override
  Future<List<PlaceData>> searchNearby(
    NearbySearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async => const <PlaceData>[];

  @override
  Future<List<PlaceData>> searchText(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    textSearchRequests.add(request);
    cancellationTokens.add(cancellationToken);
    if (textSearchError case final error?) {
      throw error;
    }
    if (textSearchRequests.length == 1 && firstTextSearch != null) {
      return firstTextSearch!.future;
    }
    return <PlaceData>[
      PlaceData(
        id: 'single-${textSearchRequests.length}',
        displayName: LocalizedText(text: 'Result for ${request.textQuery}'),
      ),
    ];
  }

  @override
  Future<TextSearchPage> searchTextPage(
    TextSearchRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) async {
    pagedSearchRequests.add(request);
    cancellationTokens.add(cancellationToken);
    final isFirstPage = request.pageToken == null;
    return TextSearchPage(
      results: <PlaceData>[
        PlaceData(
          id: isFirstPage ? 'page-1' : 'page-2',
          displayName: LocalizedText(
            text: isFirstPage ? 'First page result' : 'Second page result',
          ),
        ),
      ],
      nextPageToken: isFirstPage ? 'next-page' : null,
      searchUri: 'https://www.google.com/maps/search/${request.textQuery}',
    );
  }
}

PlacesClient _clientFor(_RecordingBackend backend) =>
    PlacesClient.testing(apiKey: 'test', backend: backend);

Future<void> _openConfiguration(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('open-configuration')));
  await tester.pumpAndSettle();
}

Future<void> _selectDropdown(
  WidgetTester tester,
  String key,
  String label,
) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _applyConfiguration(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey<String>('configuration-apply')));
  await tester.pumpAndSettle();
}

Future<void> _toggleConfigurationSwitch(
  WidgetTester tester,
  String label,
) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enablePagedSearch(WidgetTester tester, {int pageSize = 5}) async {
  await _openConfiguration(tester);
  await tester.tap(find.text('Paged').last);
  await tester.pumpAndSettle();
  if (pageSize != 5) {
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-advanced')),
    );
    await tester.pumpAndSettle();
    await _selectDropdown(tester, 'configuration-page-size', '$pageSize');
  }
  await _applyConfiguration(tester);
}

Future<void> _searchFor(WidgetTester tester, String query) async {
  final input = find.byKey(const ValueKey<String>('text-search-input'));
  await tester.ensureVisible(input);
  await tester.pumpAndSettle();
  await tester.enterText(input, query);
  await tester.tap(find.byKey(const ValueKey<String>('text-search-submit')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the missing client configuration notice by default', (
    tester,
  ) async {
    await tester.pumpWidget(const ExampleApp());

    expect(
      find.text(
        'Pass GOOGLE_MAPS_API_KEY or PLACES_PROXY_URL with --dart-define '
        'to run the example.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'shows a compact summary and keeps injected clients caller-owned',
    (tester) async {
      final backend = _RecordingBackend();
      final client = _clientFor(backend);
      await tester.pumpWidget(ExampleApp(client: client));

      expect(find.text('Current configuration'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Text Field'), findsOneWidget);
      expect(find.text('Single page'), findsOneWidget);
      expect(find.text('Place details'), findsOneWidget);
      expect(find.text('Language'), findsNothing);
      expect(find.text('Widget type'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(backend.closeCount, 0);
      await client.close();
    },
  );

  testWidgets('configuration cancel discards drafts and Apply commits them', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));

    await _openConfiguration(tester);
    await _selectDropdown(tester, 'configuration-widget-type', 'Form');
    await tester.tap(find.text('Paged').last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-cancel')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text Field'), findsOneWidget);
    expect(find.text('Single page'), findsOneWidget);
    expect(find.text('Text Field Type'), findsOneWidget);

    await _openConfiguration(tester);
    await _selectDropdown(tester, 'configuration-widget-type', 'Form');
    await tester.tap(find.text('Paged').last);
    await tester.pumpAndSettle();
    await _applyConfiguration(tester);

    expect(find.text('Form'), findsOneWidget);
    expect(find.text('Paged'), findsOneWidget);
    expect(find.text('5 per page'), findsOneWidget);
    expect(find.byType(PlacesAutocompleteFormField), findsOneWidget);
    expect(find.text('Text Field Type'), findsNothing);
    await client.close();
  });

  testWidgets('language applies with RTL only after confirmation', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));

    await _openConfiguration(tester);
    await _selectDropdown(tester, 'configuration-language', 'עברית');
    expect(
      Directionality.of(tester.element(find.text('Configuration').last)),
      TextDirection.ltr,
    );
    await _applyConfiguration(tester);

    expect(find.text('עברית'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Current configuration'))),
      TextDirection.rtl,
    );
    await client.close();
  });

  testWidgets('advanced settings are summarized and forwarded to the field', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));

    await _openConfiguration(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-advanced')),
    );
    await tester.pumpAndSettle();
    await _toggleConfigurationSwitch(tester, 'Fetch Place Details');
    await _toggleConfigurationSwitch(tester, 'Fetch Time Zone');
    await _toggleConfigurationSwitch(tester, 'Include query predictions');
    await _toggleConfigurationSwitch(tester, 'Show distance from an origin');
    await _applyConfiguration(tester);

    expect(find.text('Place details'), findsNothing);
    expect(find.text('Time zone'), findsOneWidget);
    expect(find.text('Query predictions'), findsOneWidget);
    expect(find.text('Distance from origin'), findsOneWidget);
    final field = tester.widget<PlacesAutocompleteField>(
      find.byType(PlacesAutocompleteField),
    );
    expect(field.fetchPlaceDetailsOnSelection, isFalse);
    expect(field.fetchTimeZoneOnSelection, isTrue);
    expect(field.includeQueryPredictions, isTrue);
    expect(field.origin, DemoConfiguration.demoOrigin);
    await client.close();
  });

  testWidgets('the field decoration survives every launcher mode', (
    tester,
  ) async {
    // Dialog and fullscreen launchers used to drop the field's decoration
    // entirely, because the overlay never received it.
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));

    expect(find.text('Address'), findsOneWidget);

    for (final mode in <String>['Dialog', 'Fullscreen']) {
      await _openConfiguration(tester);
      await _selectDropdown(tester, 'configuration-widget-type', mode);
      await _applyConfiguration(tester);

      await tester.tap(find.text('Click to Search'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PlacesAutocompleteOverlay),
          matching: find.text('Address'),
        ),
        findsOneWidget,
        reason: '$mode mode must honour the field decoration',
      );

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
    await client.close();
  });

  testWidgets('widget choices keep field-mode tabs only for Text Field', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));

    expect(find.text('Text Field Type'), findsOneWidget);
    for (final type in <String>['Form', 'Dialog', 'Fullscreen']) {
      await _openConfiguration(tester);
      await _selectDropdown(tester, 'configuration-widget-type', type);
      await _applyConfiguration(tester);
      expect(find.text(type), findsOneWidget);
      expect(find.text('Text Field Type'), findsNothing);
      if (type == 'Form') {
        expect(find.byType(PlacesAutocompleteFormField), findsOneWidget);
      } else {
        expect(find.text('Click to Search'), findsOneWidget);
      }
    }
    await client.close();
  });

  testWidgets('single-page Text Search uses the entered query', (tester) async {
    final backend = _RecordingBackend();
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));

    await _searchFor(tester, 'pizza in Haifa');

    expect(backend.textSearchRequests, hasLength(1));
    expect(backend.pagedSearchRequests, isEmpty);
    expect(backend.textSearchRequests.single.textQuery, 'pizza in Haifa');
    expect(find.text('Result for pizza in Haifa'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('text-search-load-more')),
      findsNothing,
    );
    await client.close();
  });

  testWidgets('Text Search clear removes the query and previous results', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));
    await _searchFor(tester, 'restaurants');

    expect(find.text('Result for restaurants'), findsOneWidget);
    final clear = find.byKey(const ValueKey<String>('text-search-clear'));
    await tester.ensureVisible(clear);
    await tester.pumpAndSettle();
    await tester.tap(clear);
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('text-search-input')),
    );
    expect(field.controller!.text, isEmpty);
    expect(find.text('Result for restaurants'), findsNothing);
    expect(find.textContaining('result(s)'), findsNothing);
    expect(clear, findsNothing);
    await client.close();
  });

  testWidgets('paged Text Search appends pages and forwards page settings', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));
    await _enablePagedSearch(tester, pageSize: 10);

    await _searchFor(tester, 'parks');
    expect(backend.pagedSearchRequests, hasLength(1));
    expect(backend.pagedSearchRequests.first.textQuery, 'parks');
    expect(backend.pagedSearchRequests.first.pageSize, 10);
    expect(backend.pagedSearchRequests.first.pageToken, isNull);
    expect(find.text('First page result'), findsOneWidget);

    final loadMore = find.byKey(
      const ValueKey<String>('text-search-load-more'),
    );
    await tester.ensureVisible(loadMore);
    await tester.tap(loadMore);
    await tester.pumpAndSettle();

    expect(backend.pagedSearchRequests, hasLength(2));
    expect(backend.pagedSearchRequests.last.pageToken, 'next-page');
    expect(find.text('First page result'), findsOneWidget);
    expect(find.text('Second page result'), findsOneWidget);
    expect(find.text('2 result(s) across 2 page(s)'), findsOneWidget);
    expect(loadMore, findsNothing);
    await client.close();
  });

  testWidgets('empty Text Search queries show local validation', (
    tester,
  ) async {
    final client = _clientFor(_RecordingBackend());
    await tester.pumpWidget(ExampleApp(client: client));
    final submit = find.byKey(const ValueKey<String>('text-search-submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Enter a place search.'), findsOneWidget);
    await client.close();
  });

  testWidgets('a replacement search cancels and ignores stale results', (
    tester,
  ) async {
    final backend = _RecordingBackend();
    backend.firstTextSearch = Completer<List<PlaceData>>();
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));
    final input = find.byKey(const ValueKey<String>('text-search-input'));
    await tester.ensureVisible(input);

    await tester.enterText(input, 'old query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    await tester.enterText(input, 'new query');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();

    expect(backend.textSearchRequests, hasLength(2));
    expect(backend.cancellationTokens.first!.isCancelled, isTrue);
    expect(find.text('Result for new query'), findsOneWidget);

    backend.firstTextSearch!.complete(const <PlaceData>[
      PlaceData(
        id: 'stale',
        displayName: LocalizedText(text: 'Stale result'),
      ),
    ]);
    await tester.pumpAndSettle();
    expect(find.text('Stale result'), findsNothing);
    await client.close();
  });

  testWidgets('Text Search errors stay in the Text Search section', (
    tester,
  ) async {
    final backend = _RecordingBackend()
      ..textSearchError = const PlacesException(
        'Temporary search failure.',
        kind: PlacesErrorKind.network,
        operation: PlacesOperation.textSearch,
        retryable: true,
      );
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));

    await _searchFor(tester, 'museums');
    expect(find.textContaining('Temporary search failure.'), findsOneWidget);
    expect(find.textContaining('network · textSearch'), findsOneWidget);
    await client.close();
  });

  testWidgets('a pick shows its coordinates and parsed address', (
    tester,
  ) async {
    final backend = _RecordingBackend()
      ..suggestions = const <PlaceSuggestion>[
        PlaceSuggestion(
          placeId: 'place-1',
          placeResourceName: 'places/place-1',
          fullText: StructuredText(text: 'Coffee Lab, Main Street'),
          primaryText: StructuredText(text: 'Coffee Lab'),
          secondaryText: StructuredText(text: 'Main Street'),
        ),
      ]
      ..place = const PlaceData(
        id: 'place-1',
        formattedAddress: '151 Broadway, New York, NY 10007, USA',
        location: PlaceCoordinates(latitude: 40.71, longitude: -74.01),
        addressComponents: <PlaceAddressComponent>[
          PlaceAddressComponent(
            longText: '151',
            types: <String>['street_number'],
          ),
          PlaceAddressComponent(longText: 'Broadway', types: <String>['route']),
          PlaceAddressComponent(
            longText: 'New York',
            types: <String>['locality'],
          ),
          PlaceAddressComponent(
            longText: 'United States',
            shortText: 'US',
            types: <String>['country'],
          ),
        ],
      );
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));

    await tester.enterText(find.byType(TextField).first, 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pumpAndSettle();

    for (final line in <String>[
      'location: 40.71, -74.01',
      'streetAddress: 151 Broadway',
      'city: New York',
      'countryShort: US',
    ]) {
      await tester.ensureVisible(find.text(line));
      expect(find.text(line), findsOneWidget);
    }
    await client.close();
  });

  testWidgets('the photo setting requests photos and shows them in a strip', (
    tester,
  ) async {
    // Lets Image.network load the photo without the network.
    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 4),
    );
    imageCache.putIfAbsent(
      const NetworkImage('https://example.com/photo.jpg'),
      () => OneFrameImageStreamCompleter(
        SynchronousFuture<ImageInfo>(ImageInfo(image: image!)),
      ),
    );
    addTearDown(imageCache.clear);
    final backend = _RecordingBackend()
      ..suggestions = const <PlaceSuggestion>[
        PlaceSuggestion(
          placeId: 'place-1',
          placeResourceName: 'places/place-1',
          fullText: StructuredText(text: 'Coffee Lab, Main Street'),
          primaryText: StructuredText(text: 'Coffee Lab'),
          secondaryText: StructuredText(text: 'Main Street'),
        ),
      ]
      ..place = const PlaceData(
        id: 'place-1',
        photos: <PlacePhoto>[
          PlacePhoto(
            name: 'places/place-1/photos/photo-1',
            googleMapsUri: 'https://maps.google.com/photo-1',
            authorAttributions: <Map<String, Object?>>[
              <String, Object?>{'displayName': 'Ana Lima'},
            ],
          ),
        ],
      );
    final client = _clientFor(backend);
    await tester.pumpWidget(ExampleApp(client: client));

    expect(find.text('Photos'), findsOneWidget, reason: 'summary chip');
    await tester.enterText(find.byType(TextField).first, 'cof');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coffee Lab'));
    await tester.pumpAndSettle();

    expect(backend.detailsRequests.single.fields, contains(PlaceField.photos));
    final strip = find.byKey(const ValueKey<String>('photo-strip'));
    await tester.ensureVisible(strip);
    await tester.pumpAndSettle();
    expect(find.byType(PlacePhotoView), findsOneWidget);
    expect(backend.photoRequests.single.maxHeightPx, isNotNull);
    // Outside the browser the Maps link is drawn only with onOpenLink.
    expect(
      find.text('Photo by Ana Lima · View on Google Maps'),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
    await tester.pumpAndSettle();
    await _openConfiguration(tester);
    await tester.tap(
      find.byKey(const ValueKey<String>('configuration-advanced')),
    );
    await tester.pumpAndSettle();
    await _toggleConfigurationSwitch(tester, 'Show place photos');
    await _applyConfiguration(tester);

    expect(find.byType(PlacePhotoView), findsNothing);
    final field = tester.widget<PlacesAutocompleteField>(
      find.byType(PlacesAutocompleteField),
    );
    expect(field.selectionFields, isNot(contains(PlaceField.photos)));
    await client.close();
  });
}
