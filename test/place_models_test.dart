import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_autocomplete/google_places_autocomplete.dart';

void main() {
  group('AutocompleteRequest', () {
    test('serializes the new API request shape', () {
      final request = AutocompleteRequest(
        input: 'coffee',
        sessionToken: AutocompleteSessionToken.fromValue('session'),
        languageCode: 'en',
        regionCode: 'us',
        locationBias: LocationBias.circle(
          center: const PlaceCoordinates(latitude: 32.08, longitude: 34.78),
          radiusMeters: 500,
        ),
        includedPrimaryTypes: const <String>['cafe'],
        includedRegionCodes: const <String>['us'],
        includePureServiceAreaBusinesses: true,
      );

      expect(request.toRestJson(), <String, Object?>{
        'input': 'coffee',
        'sessionToken': 'session',
        'languageCode': 'en',
        'regionCode': 'us',
        'locationBias': <String, Object?>{
          'circle': <String, Object?>{
            'center': <String, Object?>{'latitude': 32.08, 'longitude': 34.78},
            'radius': 500.0,
          },
        },
        'includedPrimaryTypes': const <String>['cafe'],
        'includedRegionCodes': const <String>['us'],
        'includePureServiceAreaBusinesses': true,
      });
    });

    test('rejects simultaneous bias and restriction', () {
      final request = AutocompleteRequest(
        input: 'coffee',
        locationBias: LocationBias.circle(
          center: const PlaceCoordinates(latitude: 0, longitude: 0),
          radiusMeters: 100,
        ),
        locationRestriction: LocationRestriction.circle(
          center: const PlaceCoordinates(latitude: 0, longitude: 0),
          radiusMeters: 100,
        ),
      );

      expect(request.validate, throwsA(isA<PlacesException>()));
    });
  });

  test('parses rich place data', () {
    final place = PlaceData.fromJson(<String, Object?>{
      'id': 'place-1',
      'name': 'places/place-1',
      'displayName': <String, Object?>{
        'text': 'Coffee Lab',
        'languageCode': 'en',
      },
      'formattedAddress': '1 Main St',
      'postalAddress': <String, Object?>{
        'regionCode': 'US',
        'administrativeArea': 'NY',
        'locality': 'New York',
        'postalCode': '10036',
      },
      'addressComponents': <Map<String, Object?>>[
        <String, Object?>{
          'longText': 'Times Square',
          'shortText': 'Times Square',
          'types': <String>['route'],
          'languageCode': 'en',
        },
        <String, Object?>{
          'longText': '1',
          'shortText': '1',
          'types': <String>['street_number'],
          'languageCode': 'en',
        },
        <String, Object?>{
          'longText': 'New York',
          'shortText': 'NYC',
          'types': <String>['locality'],
          'languageCode': 'en',
        },
        <String, Object?>{
          'longText': 'New York',
          'shortText': 'NY',
          'types': <String>['administrative_area_level_1'],
          'languageCode': 'en',
        },
        <String, Object?>{
          'longText': '10036',
          'shortText': '10036',
          'types': <String>['postal_code'],
          'languageCode': 'en',
        },
        <String, Object?>{
          'longText': 'United States',
          'shortText': 'US',
          'types': <String>['country'],
          'languageCode': 'en',
        },
      ],
      'location': <String, Object?>{'latitude': 1.2, 'longitude': 3.4},
      'rating': 4.7,
      'userRatingCount': 128,
      'photos': <Map<String, Object?>>[
        <String, Object?>{'name': 'photo-1', 'widthPx': 800, 'heightPx': 600},
      ],
    });

    expect(place.id, 'place-1');
    expect(place.resourceName, 'places/place-1');
    expect(place.displayName?.text, 'Coffee Lab');
    expect(place.location?.latitude, 1.2);
    expect(place.postalAddress?.locality, 'New York');
    expect(place.addressComponents, hasLength(6));
    expect(place.route, 'Times Square');
    expect(place.routeShort, 'Times Square');
    expect(place.streetNumber, '1');
    expect(place.streetNumberShort, '1');
    expect(place.locality, 'New York');
    expect(place.localityShort, 'NYC');
    expect(place.administrativeArea, 'New York');
    expect(place.administrativeAreaShort, 'NY');
    expect(place.postalCode, '10036');
    expect(place.postalCodeShort, '10036');
    expect(place.country, 'United States');
    expect(place.countryShort, 'US');
    expect(place.countryCode, 'US');
    expect(place.countryCodeShort, 'US');
    expect(place.photos, hasLength(1));
  });

  test('parses time-zone data', () {
    final timestamp = DateTime.utc(2026, 4, 15, 12);
    final timeZone = PlaceTimeZoneData.fromJson(<String, Object?>{
      'dstOffset': 3600,
      'rawOffset': -18000,
      'timeZoneId': 'America/New_York',
      'timeZoneName': 'Eastern Daylight Time',
      'status': 'OK',
    }, timestamp: timestamp);

    expect(timeZone.dstOffset, const Duration(hours: 1));
    expect(timeZone.rawOffset, const Duration(hours: -5));
    expect(timeZone.timeZoneId, 'America/New_York');
    expect(timeZone.timestamp, timestamp);
  });

  test('creates time-zone request from place coordinates', () {
    final request = TimeZoneRequest.fromPlace(
      const PlaceData(
        id: 'place-1',
        location: PlaceCoordinates(latitude: 32.08, longitude: 34.78),
      ),
      timestamp: DateTime.utc(2026, 4, 15),
      languageCode: 'en',
    );

    expect(request.location.latitude, 32.08);
    expect(request.languageCode, 'en');
  });

  test('rejects time-zone request from place without location', () {
    expect(
      () => TimeZoneRequest.fromPlace(const PlaceData(id: 'place-1')),
      throwsA(isA<PlacesException>()),
    );
  });
}
