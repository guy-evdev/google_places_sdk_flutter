import 'package:flutter_test/flutter_test.dart';
import 'package:google_places_sdk_flutter/google_places_sdk_flutter.dart';
import 'package:google_places_sdk_flutter/src/internal/place_field_mapping.dart';

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
        includeFutureOpeningBusinesses: true,
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
        'includeFutureOpeningBusinesses': true,
      });
    });

    test('serializes query prediction opt-in', () {
      const request = AutocompleteRequest(
        input: 'coffee',
        includeQueryPredictions: true,
      );

      expect(request.toRestJson()['includeQueryPredictions'], isTrue);
    });

    test('parses query predictions', () {
      final suggestion = AutocompleteSuggestion.fromRestJson(<String, Object?>{
        'queryPrediction': <String, Object?>{
          'text': <String, Object?>{
            'text': 'coffee near me',
            'matches': <Map<String, Object?>>[
              <String, Object?>{'startOffset': 0, 'endOffset': 6},
            ],
          },
        },
      });

      expect(suggestion, isA<QuerySuggestion>());
      expect(suggestion.displayText, 'coffee near me');
      expect((suggestion as QuerySuggestion).matches.single.endOffset, 6);
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

    test(
      'validates cursor, type, region, coordinate, and token constraints',
      () {
        expect(
          () => const AutocompleteRequest(
            input: '😀a',
            inputOffset: 3,
          ).validate(),
          throwsA(
            isA<PlacesException>()
                .having(
                  (error) => error.kind,
                  'kind',
                  PlacesErrorKind.validation,
                )
                .having((error) => error.code, 'code', 'invalid_input_offset'),
          ),
        );
        expect(
          () => const AutocompleteRequest(
            input: 'coffee',
            includedPrimaryTypes: <String>[
              'cafe',
              'bakery',
              'restaurant',
              'bar',
              'store',
              'museum',
            ],
          ).validate(),
          throwsA(isA<PlacesException>()),
        );
        expect(
          () => const AutocompleteRequest(
            input: 'coffee',
            includedPrimaryTypes: <String>['(cities)', 'cafe'],
          ).validate(),
          throwsA(isA<PlacesException>()),
        );
        expect(
          () => const AutocompleteRequest(
            input: 'coffee',
            includedRegionCodes: <String>['usa'],
          ).validate(),
          throwsA(isA<PlacesException>()),
        );
        expect(
          () => AutocompleteRequest(
            input: 'coffee',
            origin: const PlaceCoordinates(latitude: 91, longitude: 0),
            sessionToken: AutocompleteSessionToken.fromValue('not safe!'),
          ).validate(),
          throwsA(isA<PlacesException>()),
        );
      },
    );
  });

  group('search request pagination', () {
    test('serializes Text Search page and business filters', () {
      const request = TextSearchRequest(
        textQuery: 'coffee',
        pageSize: 10,
        pageToken: 'next-token',
        priceLevels: <PlacePriceLevel>[
          PlacePriceLevel.inexpensive,
          PlacePriceLevel.moderate,
        ],
        includePureServiceAreaBusinesses: true,
        includeFutureOpeningBusinesses: true,
      );

      expect(request.toRestJson(), containsPair('pageSize', 10));
      expect(request.toRestJson(), containsPair('pageToken', 'next-token'));
      expect(request.toRestJson()['priceLevels'], <String>[
        'PRICE_LEVEL_INEXPENSIVE',
        'PRICE_LEVEL_MODERATE',
      ]);
      expect(request.toRestJson()['includePureServiceAreaBusinesses'], isTrue);
      expect(request.toRestJson()['includeFutureOpeningBusinesses'], isTrue);
    });

    test('rejects response-only price levels as filters', () {
      const request = TextSearchRequest(
        textQuery: 'coffee',
        priceLevels: <PlacePriceLevel>[PlacePriceLevel.free],
      );

      expect(request.validate, throwsA(isA<PlacesException>()));
    });

    test('drops deprecated maxResultCount when pageSize is set', () {
      const request = TextSearchRequest(
        textQuery: 'coffee',
        pageSize: 10,
        // ignore: deprecated_member_use_from_same_package
        maxResultCount: 5,
      );

      final json = request.toRestJson();

      expect(json['pageSize'], 10);
      expect(
        json.containsKey('maxResultCount'),
        isFalse,
        reason:
            'Google ignores maxResultCount when pageSize is present, and the '
            'Maps JavaScript path already drops it. Sending both made REST '
            'and web disagree for the same request.',
      );
    });

    test('still sends deprecated maxResultCount when pageSize is absent', () {
      const request = TextSearchRequest(
        textQuery: 'coffee',
        // ignore: deprecated_member_use_from_same_package
        maxResultCount: 5,
      );

      final json = request.toRestJson();

      expect(json.containsKey('pageSize'), isFalse);
      expect(json['maxResultCount'], 5);
    });

    test('parses metadata and defensively copies Text Search results', () {
      final source = <PlaceData>[const PlaceData(id: 'place-1')];
      final page = TextSearchPage.fromJson(<String, Object?>{
        'places': <Map<String, Object?>>[
          <String, Object?>{'id': 'place-1'},
        ],
        'nextPageToken': 'next-token',
        'searchUri': 'https://www.google.com/maps/search/coffee',
      });
      final copiedPage = TextSearchPage(results: source);
      source.add(const PlaceData(id: 'place-2'));

      expect(page.results.single.id, 'place-1');
      expect(page.hasNextPage, isTrue);
      expect(page.nextPageToken, 'next-token');
      expect(page.searchUri, contains('/maps/search/coffee'));
      expect(copiedPage.results, hasLength(1));
      expect(
        () => copiedPage.results.add(const PlaceData(id: 'place-3')),
        throwsUnsupportedError,
      );
    });

    test('serializes future-opening filter for Nearby Search', () {
      final request = NearbySearchRequest(
        locationRestriction: LocationRestriction.circle(
          center: const PlaceCoordinates(latitude: 32.08, longitude: 34.78),
          radiusMeters: 500,
        ),
        includeFutureOpeningBusinesses: true,
      );

      expect(request.toRestJson()['includeFutureOpeningBusinesses'], isTrue);
    });

    test('validates Text Search bounds, fields, and restriction shape', () {
      expect(
        () => const TextSearchRequest(
          textQuery: 'coffee',
          pageSize: 21,
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => const TextSearchRequest(
          textQuery: 'coffee',
          fields: <PlaceField>{},
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => TextSearchRequest(
          textQuery: 'coffee',
          minRating: 5.1,
          locationRestriction: LocationRestriction.circle(
            center: const PlaceCoordinates(latitude: 0, longitude: 0),
            radiusMeters: 10,
          ),
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
    });

    test('validates Nearby Search shape, radius, counts, and conflicts', () {
      expect(
        () => NearbySearchRequest(
          locationRestriction: LocationRestriction.rectangle(
            low: const PlaceCoordinates(latitude: 0, longitude: 0),
            high: const PlaceCoordinates(latitude: 1, longitude: 1),
          ),
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => NearbySearchRequest(
          locationRestriction: LocationRestriction.circle(
            center: const PlaceCoordinates(latitude: 0, longitude: 0),
            radiusMeters: 0,
          ),
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => NearbySearchRequest(
          locationRestriction: LocationRestriction.circle(
            center: const PlaceCoordinates(latitude: 0, longitude: 0),
            radiusMeters: 100,
          ),
          includedTypes: const <String>['cafe'],
          excludedTypes: const <String>['cafe'],
          maxResultCount: 21,
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
    });
  });

  test(
    'validates details, coordinates, session tokens, and error redaction',
    () {
      expect(
        () => const PlaceDetailsRequest(placeId: '').validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => const PlaceDetailsRequest(
          placeId: 'place-1',
          fields: <PlaceField>{},
        ).validate(),
        throwsA(isA<PlacesException>()),
      );
      expect(
        () => const TimeZoneRequest(
          location: PlaceCoordinates(latitude: 0, longitude: 181),
        ).validate(),
        throwsA(isA<PlacesException>()),
      );

      final token = AutocompleteSessionToken.fromValue('private_session');
      const error = PlacesException(
        'Safe message',
        kind: PlacesErrorKind.network,
        operation: PlacesOperation.autocomplete,
      );
      expect(token.toString(), isNot(contains(token.value)));
      expect(error.toString(), isNot(contains('private_session')));
    },
  );

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
      'addressDescriptor': <String, Object?>{'landmarks': <Object?>[]},
      'evChargeOptions': <String, Object?>{'connectorCount': 2},
      'fuelOptions': <String, Object?>{'fuelPrices': <Object?>[]},
      'generativeSummary': <String, Object?>{
        'overview': <String, Object?>{'text': 'A popular coffee shop.'},
      },
      'pureServiceAreaBusiness': false,
      'movedPlace': 'places/place-2',
      'movedPlaceId': 'place-2',
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
    expect(place.addressDescriptor, isNotNull);
    expect(place.evChargeOptions?['connectorCount'], 2);
    expect(place.fuelOptions, isNotNull);
    expect(place.generativeSummary, isNotNull);
    expect(place.pureServiceAreaBusiness, isFalse);
    expect(place.movedPlace, 'places/place-2');
    expect(place.movedPlaceId, 'place-2');
  });

  test('parses stable Place resource additions into typed accessors', () {
    final place = PlaceData.fromJson(<String, Object?>{
      'id': 'station-1',
      'adrFormatAddress': '<span>1 Main St</span>',
      'plusCode': <String, Object?>{
        'globalCode': '849VCWC8+R9',
        'compoundCode': 'CWC8+R9 New York, NY',
      },
      'googleMapsTypeLabel': <String, Object?>{'text': 'Transit station'},
      'openingDate': <String, Object?>{'year': 2027, 'month': 4, 'day': 5},
      'googleMapsLinks': <String, Object?>{
        'directionsUri': 'https://maps.google.com/directions',
        'placeUri': 'https://maps.google.com/place',
        'writeAReviewUri': 'https://maps.google.com/write-review',
        'reviewsUri': 'https://maps.google.com/reviews',
        'photosUri': 'https://maps.google.com/photos',
      },
      'priceLevel': 'PRICE_LEVEL_MODERATE',
      'priceRange': <String, Object?>{
        'startPrice': <String, Object?>{
          'currencyCode': 'USD',
          'units': '10',
          'nanos': 500000000,
        },
        'endPrice': <String, Object?>{
          'currencyCode': 'USD',
          'units': '25',
          'nanos': 0,
        },
      },
      'attributions': <Map<String, Object?>>[
        <String, Object?>{
          'provider': 'Example provider',
          'providerUri': 'https://example.com',
        },
      ],
      'timeZone': <String, Object?>{'id': 'America/New_York', 'version': '1'},
      'editorialSummary': <String, Object?>{
        'text': 'A central transit hub.',
        'languageCode': 'en',
      },
      'paymentOptions': <String, Object?>{
        'acceptsCreditCards': true,
        'acceptsNfc': true,
      },
      'parkingOptions': <String, Object?>{'paidParkingLot': true},
      'accessibilityOptions': <String, Object?>{
        'wheelchairAccessibleEntrance': true,
      },
      'subDestinations': <Map<String, Object?>>[
        <String, Object?>{'id': 'platform-1', 'name': 'places/platform-1'},
      ],
      'containingPlaces': <Map<String, Object?>>[
        <String, Object?>{'id': 'building-1', 'name': 'places/building-1'},
      ],
      'currentSecondaryOpeningHours': <Map<String, Object?>>[
        <String, Object?>{
          'secondaryHoursType': 'DRIVE_THROUGH',
          'weekdayDescriptions': <String>['Monday: 9:00 AM – 5:00 PM'],
        },
      ],
      'regularSecondaryOpeningHours': <Map<String, Object?>>[
        <String, Object?>{
          'secondaryHoursType': 'DELIVERY',
          'periods': <Map<String, Object?>>[
            <String, Object?>{
              'open': <String, Object?>{'day': 1, 'hour': 9},
            },
          ],
        },
      ],
      'curbsidePickup': true,
      'servesBrunch': true,
      'servesVegetarianFood': true,
      'servesCocktails': true,
      'liveMusic': true,
      'menuForChildren': true,
      'allowsDogs': true,
      'goodForWatchingSports': true,
      'reviewSummary': <String, Object?>{
        'text': <String, Object?>{'text': 'Generally praised.'},
      },
      'evChargeAmenitySummary': <String, Object?>{
        'overview': <String, Object?>{'text': 'Coffee nearby.'},
      },
      'neighborhoodSummary': <String, Object?>{
        'overview': <String, Object?>{'text': 'Busy commercial district.'},
      },
      'consumerAlert': <String, Object?>{
        'overview': <String, Object?>{'text': 'Entrance work in progress.'},
      },
      'transitStation': <String, Object?>{
        'displayName': <String, Object?>{'text': 'Central Station'},
        'agencies': <Map<String, Object?>>[
          <String, Object?>{
            'displayName': <String, Object?>{'text': 'Metro'},
            'lines': <Map<String, Object?>>[
              <String, Object?>{
                'id': 'A',
                'vehicleType': 'SUBWAY',
                'displayName': <String, Object?>{'text': 'A Line'},
              },
            ],
          },
        ],
        'stops': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'stop-1',
            'displayName': <String, Object?>{'text': 'Platform 1'},
            'location': <String, Object?>{'latitude': 40.7, 'longitude': -74.0},
            'wheelchairAccessibleEntrance': true,
          },
        ],
      },
    });

    expect(place.adrFormatAddress, contains('1 Main St'));
    expect(place.plusCode?.globalCode, '849VCWC8+R9');
    expect(place.googleMapsTypeLabel?.text, 'Transit station');
    expect(place.openingDate?.isComplete, isTrue);
    expect(place.openingDate?.year, 2027);
    expect(place.googleMapsLinks?.photosUri, endsWith('/photos'));
    expect(place.priceLevelValue, PlacePriceLevel.moderate);
    expect(place.priceRange?.startPrice?.units, '10');
    expect(place.priceRange?.startPrice?.nanos, 500000000);
    expect(place.attributions.single.provider, 'Example provider');
    expect(place.timeZone?.id, 'America/New_York');
    expect(place.editorialSummary?.text, 'A central transit hub.');
    expect(place.paymentOptions?.acceptsNfc, isTrue);
    expect(place.parkingOptions?.paidParkingLot, isTrue);
    expect(place.accessibilityOptions?.wheelchairAccessibleEntrance, isTrue);
    expect(place.subDestinations.single.id, 'platform-1');
    expect(place.containingPlaces.single.resourceName, 'places/building-1');
    expect(place.curbsidePickup, isTrue);
    expect(place.servesBrunch, isTrue);
    expect(place.servesVegetarianFood, isTrue);
    expect(place.servesCocktails, isTrue);
    expect(place.liveMusic, isTrue);
    expect(place.menuForChildren, isTrue);
    expect(place.allowsDogs, isTrue);
    expect(place.goodForWatchingSports, isTrue);
    expect(place.transitStation?.displayName?.text, 'Central Station');
    expect(place.transitStation?.agencies.single.lines.single.id, 'A');
    expect(place.transitStation?.stops.single.location?.latitude, 40.7);

    expect(
      () => place.attributions.add(const PlaceAttribution(provider: 'x')),
      throwsUnsupportedError,
    );
    expect(
      () => place.currentSecondaryOpeningHours.single['new'] = true,
      throwsUnsupportedError,
    );
    expect(
      () =>
          (place.regularSecondaryOpeningHours.single['periods']!
                  as List<Object?>)
              .add(<String, Object?>{}),
      throwsUnsupportedError,
    );
    expect(
      () => (place.reviewSummary!['text']! as Map<String, Object?>)['text'] =
          'changed',
      throwsUnsupportedError,
    );
    expect(
      () => place.transitStation!.agencies.add(
        PlaceTransitAgency(displayName: const LocalizedText(text: 'Other')),
      ),
      throwsUnsupportedError,
    );
    expect(() => place.rawData['id'] = 'changed', throwsUnsupportedError);

    final javascriptShape = PlaceData.fromJson(<String, Object?>{
      'id': 'web-place',
      'attributions': <Map<String, Object?>>[
        <String, Object?>{
          'provider': 'Web provider',
          'providerURI': 'https://example.com/provider',
        },
      ],
      'googleMapsLinks': <String, Object?>{
        'directionsURI': 'https://maps.google.com/directions',
        'placeURI': 'https://maps.google.com/place',
      },
      'paymentOptions': <String, Object?>{'acceptsNFC': true},
      'parkingOptions': <String, Object?>{'hasPaidParkingLot': true},
      'accessibilityOptions': <String, Object?>{
        'hasWheelchairAccessibleEntrance': true,
      },
      'containingPlaces': <Map<String, Object?>>[
        <String, Object?>{'id': 'parent', 'resourceName': 'places/parent'},
      ],
      'transitStation': <String, Object?>{
        'agencies': <Map<String, Object?>>[
          <String, Object?>{'fareURL': 'https://example.com/fares'},
        ],
        'stops': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'stop',
            'hasWheelchairAccessibleEntrance': true,
          },
        ],
      },
    });

    expect(javascriptShape.googleMapsLinks?.placeUri, endsWith('/place'));
    expect(
      javascriptShape.attributions.single.providerUri,
      'https://example.com/provider',
    );
    expect(javascriptShape.paymentOptions?.acceptsNfc, isTrue);
    expect(javascriptShape.parkingOptions?.paidParkingLot, isTrue);
    expect(
      javascriptShape.accessibilityOptions?.wheelchairAccessibleEntrance,
      isTrue,
    );
    expect(
      javascriptShape.containingPlaces.single.resourceName,
      'places/parent',
    );
    expect(
      javascriptShape.transitStation?.agencies.single.fareUrl,
      'https://example.com/fares',
    );
    expect(
      javascriptShape.transitStation?.stops.single.wheelchairAccessibleEntrance,
      isTrue,
    );
  });

  test('exposes current stable Place resource fields in field masks', () {
    const fields = <PlaceField>{
      PlaceField.googleMapsTypeLabel,
      PlaceField.openingDate,
      PlaceField.googleMapsLinks,
      PlaceField.priceRange,
      PlaceField.plusCode,
      PlaceField.attributions,
      PlaceField.timeZone,
      PlaceField.editorialSummary,
      PlaceField.currentSecondaryOpeningHours,
      PlaceField.regularSecondaryOpeningHours,
      PlaceField.containingPlaces,
      PlaceField.subDestinations,
      PlaceField.curbsidePickup,
      PlaceField.servesBrunch,
      PlaceField.servesVegetarianFood,
      PlaceField.servesCocktails,
      PlaceField.liveMusic,
      PlaceField.menuForChildren,
      PlaceField.allowsDogs,
      PlaceField.goodForWatchingSports,
      PlaceField.addressDescriptor,
      PlaceField.evChargeOptions,
      PlaceField.fuelOptions,
      PlaceField.generativeSummary,
      PlaceField.reviewSummary,
      PlaceField.evChargeAmenitySummary,
      PlaceField.neighborhoodSummary,
      PlaceField.consumerAlert,
      PlaceField.transitStation,
      PlaceField.pureServiceAreaBusiness,
      PlaceField.movedPlace,
      PlaceField.movedPlaceId,
    };

    final detailsRequest = PlaceDetailsRequest(
      placeId: 'place-1',
      fields: fields,
    );
    final searchRequest = TextSearchRequest(
      textQuery: 'coffee',
      fields: fields,
    );

    expect(
      detailsRequest.detailsFieldMask,
      fields.map((field) => field.apiName).join(','),
    );
    expect(
      searchRequest.searchFieldMask,
      fields.map((field) => field.searchMaskPath).join(','),
    );
  });

  test('maps REST field names to current Maps JavaScript Place properties', () {
    expect(webPlaceFieldName(PlaceField.openingDate), 'futureOpeningDate');
    expect(webPlaceFieldName(PlaceField.googleMapsUri), 'googleMapsURI');
    expect(webPlaceFieldName(PlaceField.curbsidePickup), 'hasCurbsidePickup');
    expect(webPlaceFieldName(PlaceField.liveMusic), 'hasLiveMusic');
    expect(webPlaceFieldName(PlaceField.menuForChildren), 'hasMenuForChildren');
    expect(
      webPlaceFieldName(PlaceField.goodForWatchingSports),
      'isGoodForWatchingSports',
    );
    expect(
      webPlaceFieldName(PlaceField.pureServiceAreaBusiness),
      'isPureServiceAreaBusiness',
    );
    expect(webPlaceFieldName(PlaceField.transitStation), 'transitStation');
  });

  test('validates and serializes photo media requests', () {
    const request = PhotoMediaRequest(
      name: 'places/place-1/photos/photo-1',
      maxWidthPx: 400,
    );

    expect(request.mediaPath, 'places/place-1/photos/photo-1/media');
    expect(request.toQueryParameters(), <String, String>{
      'maxWidthPx': '400',
      'skipHttpRedirect': 'true',
    });

    expect(
      () => const PhotoMediaRequest(name: 'photo').toQueryParameters(),
      throwsA(isA<PlacesException>()),
    );
    expect(
      () => const PhotoMediaRequest(
        name: 'places/place-1/photos/photo-1',
        maxWidthPx: 4801,
      ).toQueryParameters(),
      throwsA(isA<PlacesException>()),
    );
  });

  test('parses typed photo author attributions', () {
    final photo = PlacePhoto.fromJson(<String, Object?>{
      'name': 'places/place-1/photos/photo-1',
      'authorAttributions': <Map<String, Object?>>[
        <String, Object?>{
          'displayName': 'Ada Lovelace',
          'uri': 'https://maps.google.com/contrib/ada',
          'photoUri': 'https://example.com/ada.jpg',
        },
      ],
    });

    expect(photo.authors.single.displayName, 'Ada Lovelace');
    expect(photo.authors.single.uri, contains('/contrib/ada'));
    expect(photo.authors.single.photoUri, endsWith('/ada.jpg'));
  });

  test('parsed photo authors are stored, not rebuilt on every read', () {
    // PlacesPhotoAttribution reads authors inside build, so re-parsing and
    // re-allocating per access meant re-allocating per frame.
    final photo = PlacePhoto.fromJson(<String, Object?>{
      'name': 'places/place-1/photos/photo-1',
      'authorAttributions': <Map<String, Object?>>[
        <String, Object?>{'displayName': 'Ada Lovelace'},
      ],
    });

    expect(identical(photo.authors, photo.authors), isTrue);
    expect(
      () => photo.authors.add(photo.authors.first),
      throwsUnsupportedError,
    );
  });

  test('a directly constructed photo still derives its attributions', () {
    // Google requires every returned attribution to be shown, so a photo built
    // from raw attributions must never silently report none.
    const photo = PlacePhoto(
      name: 'places/place-1/photos/photo-1',
      authorAttributions: <Map<String, Object?>>[
        <String, Object?>{'displayName': 'Grace Hopper'},
      ],
    );

    expect(photo.authors.single.displayName, 'Grace Hopper');
  });

  test('coordinates compare by value so widget options stay stable', () {
    // PlacesAutocompleteField.origin resets the billing session when it
    // changes. Without value equality a rebuild with a fresh instance would
    // reset the session, and the token, on every frame.
    const a = PlaceCoordinates(latitude: 40.7, longitude: -74.0);
    const b = PlaceCoordinates(latitude: 40.7, longitude: -74.0);
    const c = PlaceCoordinates(latitude: 40.7, longitude: -73.0);

    expect(PlaceCoordinates(latitude: a.latitude, longitude: a.longitude), b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
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
