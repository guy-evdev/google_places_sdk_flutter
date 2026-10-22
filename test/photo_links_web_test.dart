@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:material_ui/material_ui.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('with no onOpenLink, the browser opens the link in a new tab', (
    tester,
  ) async {
    final opened = <List<String>>[];
    final window = web.window as JSObject;
    final savedOpen = window.getProperty<JSAny?>('open'.toJS);
    window.setProperty(
      'open'.toJS,
      ((JSString url, JSString target, JSString features) {
        opened.add(<String>[url.toDart, target.toDart, features.toDart]);
      }).toJS,
    );
    addTearDown(() => window.setProperty('open'.toJS, savedOpen));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PlacesPhotoAttribution(
            photo: PlacePhoto(
              name: 'places/p1/photos/c',
              googleMapsUri: 'https://maps.google.com/photo/c',
              authorAttributions: <Map<String, Object?>>[
                <String, Object?>{
                  'displayName': 'Ana Lima',
                  'uri': '//maps.google.com/maps/contrib/1',
                },
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      find.text('Photo by Ana Lima · View on Google Maps'),
      findsOneWidget,
    );

    await tester.tapOnText(find.textRange.ofSubstring('View on Google Maps'));
    await tester.tapOnText(find.textRange.ofSubstring('Ana Lima'));
    expect(opened, <List<String>>[
      <String>[
        'https://maps.google.com/photo/c',
        '_blank',
        'noopener,noreferrer',
      ],
      <String>[
        'https://maps.google.com/maps/contrib/1',
        '_blank',
        'noopener,noreferrer',
      ],
    ]);
  });
}
