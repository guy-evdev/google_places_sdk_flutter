import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/backend.dart';
import 'package:material_ui/material_ui.dart';

/// Answers photo-media requests with completers the test resolves, so every
/// state and ordering can be driven by hand.
class _PhotoBackend implements PlacesBackend {
  final List<PhotoMediaRequest> requests = <PhotoMediaRequest>[];
  final List<PlacesCancellationToken?> tokens = <PlacesCancellationToken?>[];
  final List<Completer<PlacePhotoMedia>> responses =
      <Completer<PlacePhotoMedia>>[];

  @override
  Future<PlacePhotoMedia> fetchPhotoMedia(
    PhotoMediaRequest request, {
    PlacesCancellationToken? cancellationToken,
  }) {
    requests.add(request);
    tokens.add(cancellationToken);
    final response = Completer<PlacePhotoMedia>();
    responses.add(response);
    return response.future;
  }

  void succeed(int index, String photoUri) => responses[index].complete(
    PlacePhotoMedia(name: '${requests[index].name}/media', photoUri: photoUri),
  );

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _photo = PlacePhoto(
  name: 'places/p1/photos/a',
  widthPx: 1200,
  heightPx: 800,
  authorAttributions: <Map<String, Object?>>[
    <String, Object?>{'displayName': 'Ana Lima'},
  ],
);

const _otherPhoto = PlacePhoto(name: 'places/p1/photos/b', widthPx: 640);

/// Puts a decoded image in Flutter's image cache under [url], so
/// `Image.network(url)` loads it without touching the network.
Future<void> _seedImage(WidgetTester tester, String url) async {
  final image = await tester.runAsync(
    () => createTestImage(width: 4, height: 4),
  );
  imageCache.putIfAbsent(
    NetworkImage(url),
    () => OneFrameImageStreamCompleter(
      SynchronousFuture<ImageInfo>(ImageInfo(image: image!)),
    ),
  );
}

/// Puts an image in the cache under [url] that fails when the returned
/// completer does — after the widget has started listening to it.
Completer<ImageInfo> _seedPendingImage(String url) {
  final completer = Completer<ImageInfo>();
  imageCache.putIfAbsent(
    NetworkImage(url),
    () => OneFrameImageStreamCompleter(completer.future),
  );
  return completer;
}

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  late _PhotoBackend backend;
  late PlacesClient client;

  setUp(() {
    backend = _PhotoBackend();
    client = PlacesClient.testing(apiKey: 'test', backend: backend);
  });

  tearDown(() {
    imageCache
      ..clear()
      ..clearLiveImages();
  });

  testWidgets('loads the photo and draws its attribution over it', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/a');
    await tester.pumpWidget(
      _app(PlacePhotoView(photo: _photo, client: client, width: 200)),
    );

    expect(backend.requests.single.name, 'places/p1/photos/a');
    expect(
      find.byWidgetPredicate((widget) => widget is CircularProgressIndicator),
      findsOneWidget,
    );
    expect(find.byType(Image), findsNothing);

    backend.succeed(0, 'https://img.test/a');
    await tester.pump();

    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).width, 200);
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
    expect(find.text('Photo by Ana Lima'), findsOneWidget);
    // Image's frame builder puts the drawn RawImage inside our view.
    expect(
      find.descendant(
        of: find.ancestor(
          of: find.byType(RawImage),
          matching: find.byType(Stack),
        ),
        matching: find.byType(PlacesPhotoAttribution),
      ),
      findsOneWidget,
      reason: 'the default view draws the attribution over the image',
    );
  });

  testWidgets('a photo without author names gets no attribution', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/b');
    PlacePhotoViewData? seen;
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _otherPhoto,
          client: client,
          height: 100,
          builder: (context, photo) {
            seen = photo;
            return photo.defaultView;
          },
        ),
      ),
    );
    backend.succeed(0, 'https://img.test/b');
    await tester.pump();

    expect(seen!.status, PlacePhotoStatus.loaded);
    expect(seen!.attribution, isNull);
    expect(find.byType(PlacesPhotoAttribution), findsNothing);
  });

  testWidgets('strings set the attribution prefix and the retry text', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/a');
    const strings = PlacesStrings(
      photoAttributionPrefix: 'Photo :',
      retryText: 'Réessayer',
    );
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          strings: strings,
        ),
      ),
    );
    backend.succeed(0, 'https://img.test/a');
    await tester.pump();
    expect(find.text('Photo : Ana Lima'), findsOneWidget);

    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _otherPhoto,
          client: client,
          width: 100,
          strings: strings,
        ),
      ),
    );
    backend.responses[1].completeError(const PlacesException('down'));
    await tester.pump();
    expect(find.text('Réessayer'), findsOneWidget);
  });

  group('requested size', () {
    Future<PhotoMediaRequest> requestFor(
      WidgetTester tester,
      PlacePhotoView view,
    ) async {
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_app(view));
      return backend.requests.last;
    }

    testWidgets('width times the device pixel ratio', (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(photo: _photo, client: client, width: 100.2),
      );
      expect(request.maxWidthPx, 301);
      expect(request.maxHeightPx, isNull);
    });

    testWidgets('height alone', (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(photo: _photo, client: client, height: 50),
      );
      expect(request.maxWidthPx, isNull);
      expect(request.maxHeightPx, 150);
    });

    testWidgets('capped at 4800', (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(photo: _photo, client: client, width: 2000),
      );
      expect(request.maxWidthPx, 4800);
    });

    testWidgets('explicit pixels win over width and height', (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          height: 100,
          maxHeightPx: 64,
        ),
      );
      expect(request.maxWidthPx, isNull);
      expect(request.maxHeightPx, 64);
    });

    testWidgets("no size asks for the photo's own width", (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(photo: _photo, client: client),
      );
      expect(request.maxWidthPx, 1200);
      expect(request.maxHeightPx, isNull);
    });

    testWidgets('no size and no known width asks for 4800', (tester) async {
      final request = await requestFor(
        tester,
        PlacePhotoView(
          photo: const PlacePhoto(name: 'places/p1/photos/c'),
          client: client,
        ),
      );
      expect(request.maxWidthPx, 4800);
    });

    test('out-of-range sizes are rejected', () {
      expect(
        () => PlacePhotoView(photo: _photo, client: client, maxWidthPx: 0),
        throwsAssertionError,
      );
      expect(
        () => PlacePhotoView(photo: _photo, client: client, maxHeightPx: 4801),
        throwsAssertionError,
      );
      expect(
        () => PlacePhotoView(photo: _photo, client: client, width: 0),
        throwsAssertionError,
      );
      expect(
        () => PlacePhotoView(
          photo: _photo,
          client: client,
          height: double.infinity,
        ),
        throwsAssertionError,
      );
    });
  });

  test('exactly one of client and apiKey', () {
    expect(() => PlacePhotoView(photo: _photo), throwsAssertionError);
    expect(
      () => PlacePhotoView(photo: _photo, client: client, apiKey: 'key'),
      throwsAssertionError,
    );
  });

  testWidgets('a failed fetch shows retry, with the typed error', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/a');
    final views = <PlacePhotoViewData>[];
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) {
            views.add(photo);
            return photo.defaultView;
          },
        ),
      ),
    );
    expect(views.last.status, PlacePhotoStatus.loading);
    expect(views.last.image, isNull);

    const failure = PlacesException(
      'quota',
      kind: PlacesErrorKind.googleApi,
      statusCode: 429,
    );
    backend.responses[0].completeError(failure);
    await tester.pump();
    expect(views.last.status, PlacePhotoStatus.error);
    expect(views.last.error, same(failure));

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(backend.requests, hasLength(2));
    expect(views.last.status, PlacePhotoStatus.loading);

    backend.succeed(1, 'https://img.test/a');
    await tester.pump();
    expect(views.last.status, PlacePhotoStatus.loaded);
    expect(views.last.image, isNotNull);
    expect(views.last.error, isNull);
  });

  testWidgets('an image that fails to load is an error, wrapped', (
    tester,
  ) async {
    final image = _seedPendingImage('https://img.test/broken');
    PlacePhotoViewData? seen;
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) {
            seen = photo;
            return photo.defaultView;
          },
        ),
      ),
    );
    backend.succeed(0, 'https://img.test/broken');
    await tester.pump();
    expect(seen!.status, PlacePhotoStatus.loading, reason: 'downloading');
    image.completeError(const FormatException('not an image'));
    await tester.pump();

    expect(seen!.status, PlacePhotoStatus.error);
    expect(seen!.error!.kind, PlacesErrorKind.unknown);
    expect(seen!.error!.operation, PlacesOperation.photoMedia);
    expect(seen!.error!.metadata['errorType'], 'FormatException');
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(backend.requests, hasLength(2));

    // The failed image must have left the cache, or this good one is never
    // stored and the retry shows the old failure again.
    await _seedImage(tester, 'https://img.test/broken');
    backend.succeed(1, 'https://img.test/broken');
    await tester.pump();
    expect(seen!.status, PlacePhotoStatus.loaded);
    expect(find.text('Photo by Ana Lima'), findsOneWidget);
  });

  testWidgets('an image that downloads later moves from loading to loaded', (
    tester,
  ) async {
    final pending = _seedPendingImage('https://img.test/slow');
    final statuses = <PlacePhotoStatus>[];
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) {
            statuses.add(photo.status);
            return photo.defaultView;
          },
        ),
      ),
    );
    backend.succeed(0, 'https://img.test/slow');
    await tester.pump();
    expect(statuses.last, PlacePhotoStatus.loading);
    expect(find.byType(PlacesPhotoAttribution), findsNothing);

    final image = await tester.runAsync(
      () => createTestImage(width: 4, height: 4),
    );
    pending.complete(ImageInfo(image: image!));
    await tester.pump();
    expect(statuses.last, PlacePhotoStatus.loaded);
    expect(find.text('Photo by Ana Lima'), findsOneWidget);
  });

  testWidgets('a failed download is a retryable network error', (tester) async {
    final pending = _seedPendingImage('https://img.test/expired');
    PlacePhotoViewData? seen;
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) {
            seen = photo;
            return photo.defaultView;
          },
        ),
      ),
    );
    backend.succeed(0, 'https://img.test/expired');
    await tester.pump();
    pending.completeError(
      NetworkImageLoadException(
        statusCode: 403,
        uri: Uri.parse('https://img.test/expired'),
      ),
    );
    await tester.pump();

    expect(seen!.status, PlacePhotoStatus.error);
    expect(seen!.error!.kind, PlacesErrorKind.network);
    expect(seen!.error!.statusCode, 403);
    expect(seen!.error!.retryable, isTrue);
  });

  group('a tight box sizes the image, with the attribution on it', () {
    Future<void> expectFills(WidgetTester tester, Widget tree) async {
      await _seedImage(tester, 'https://img.test/a');
      await tester.pumpWidget(_app(tree));
      backend.succeed(0, 'https://img.test/a');
      await tester.pump();

      final view = tester.getRect(find.byType(PlacePhotoView));
      expect(tester.getRect(find.byType(RawImage)), view);
      final attribution = tester.getRect(find.byType(PlacesPhotoAttribution));
      expect(view.contains(attribution.topLeft), isTrue);
      expect(
        view.contains(attribution.bottomRight - const Offset(1, 1)),
        isTrue,
      );
    }

    testWidgets('a sized box with no size on the widget', (tester) async {
      await expectFills(
        tester,
        SizedBox(
          width: 300,
          height: 200,
          child: PlacePhotoView(photo: _photo, client: client),
        ),
      );
    });

    testWidgets('a PageView page', (tester) async {
      await expectFills(
        tester,
        SizedBox(
          width: 300,
          height: 200,
          child: PageView(
            children: <Widget>[
              PlacePhotoView(
                photo: _photo,
                client: client,
                width: 160,
                height: 120,
              ),
            ],
          ),
        ),
      );
    });
  });

  testWidgets('Google returning no photo URI is an error', (tester) async {
    PlacePhotoViewData? seen;
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) {
            seen = photo;
            return photo.defaultView;
          },
        ),
      ),
    );
    backend.succeed(0, '');
    await tester.pump();

    expect(seen!.status, PlacePhotoStatus.error);
    expect(seen!.error!.code, 'missing_photo_uri');
  });

  testWidgets('a builder replaces the look and places the attribution', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/a');
    await tester.pumpWidget(
      _app(
        PlacePhotoView(
          photo: _photo,
          client: client,
          width: 100,
          builder: (context, photo) => switch (photo.status) {
            PlacePhotoStatus.loaded => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[photo.image!, photo.attribution!],
            ),
            _ => const Text('custom placeholder'),
          },
        ),
      ),
    );
    expect(find.text('custom placeholder'), findsOneWidget);

    backend.succeed(0, 'https://img.test/a');
    await tester.pump();
    expect(
      find.ancestor(of: find.byType(RawImage), matching: find.byType(Stack)),
      findsNothing,
    );
    expect(find.text('Photo by Ana Lima'), findsOneWidget);
    expect(
      find.descendant(of: find.byType(Column), matching: find.byType(RawImage)),
      findsOneWidget,
    );
  });

  testWidgets('disposing cancels the running fetch', (tester) async {
    await tester.pumpWidget(
      _app(PlacePhotoView(photo: _photo, client: client, width: 100)),
    );
    final token = backend.tokens.single!;
    expect(token.isCancelled, isFalse);

    await tester.pumpWidget(const SizedBox());
    expect(token.isCancelled, isTrue);

    // A late answer is dropped without touching the disposed state.
    backend.succeed(0, 'https://img.test/a');
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a stale answer for the previous photo is dropped', (
    tester,
  ) async {
    await _seedImage(tester, 'https://img.test/a');
    await _seedImage(tester, 'https://img.test/b');
    await tester.pumpWidget(
      _app(PlacePhotoView(photo: _photo, client: client, width: 100)),
    );
    await tester.pumpWidget(
      _app(PlacePhotoView(photo: _otherPhoto, client: client, width: 100)),
    );
    expect(backend.requests.map((request) => request.name), <String>[
      'places/p1/photos/a',
      'places/p1/photos/b',
    ]);
    expect(backend.tokens.first!.isCancelled, isTrue);

    backend.succeed(1, 'https://img.test/b');
    await tester.pump();
    backend.succeed(0, 'https://img.test/a');
    await tester.pump();

    final image = tester.widget<Image>(find.byType(Image));
    expect((image.image as NetworkImage).url, 'https://img.test/b');
    expect(find.text('Photo by Ana Lima'), findsNothing);
  });

  testWidgets('fetches again only when photo, size or client change', (
    tester,
  ) async {
    Widget view({
      PlacePhoto photo = _photo,
      double width = 100,
      PlacesClient? withClient,
    }) => _app(
      PlacePhotoView(photo: photo, client: withClient ?? client, width: width),
    );

    await tester.pumpWidget(view());
    await tester.pumpWidget(view());
    expect(backend.requests, hasLength(1), reason: 'a rebuild keeps it');

    await tester.pumpWidget(view(width: 120));
    expect(backend.requests, hasLength(2));

    final otherBackend = _PhotoBackend();
    await tester.pumpWidget(
      view(
        width: 120,
        withClient: PlacesClient.testing(apiKey: 'test', backend: otherBackend),
      ),
    );
    expect(backend.requests, hasLength(2));
    expect(otherBackend.requests, hasLength(1));
    expect(backend.tokens.last!.isCancelled, isTrue);

    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pump();
    expect(otherBackend.requests, hasLength(2));
    expect(otherBackend.requests.last.maxWidthPx, 240);
  });

  group('PlacesPhotoAttribution', () {
    testWidgets('takes its prefix from strings', (tester) async {
      await tester.pumpWidget(
        _app(
          const PlacesPhotoAttribution(
            photo: _photo,
            strings: PlacesStrings(photoAttributionPrefix: 'Foto:'),
          ),
        ),
      );
      expect(find.text('Foto: Ana Lima'), findsOneWidget);
    });

    testWidgets('the deprecated prefix still wins', (tester) async {
      await tester.pumpWidget(
        _app(
          const PlacesPhotoAttribution(
            photo: _photo,
            // ignore: deprecated_member_use_from_same_package
            prefix: 'Image:',
            strings: PlacesStrings(photoAttributionPrefix: 'Foto:'),
          ),
        ),
      );
      expect(find.text('Image: Ana Lima'), findsOneWidget);
    });
  });
}
