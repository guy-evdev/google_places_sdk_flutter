import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

@immutable
/// Exception thrown for invalid requests or Places API failures.
class PlacesException implements Exception {
  const PlacesException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => 'PlacesException($statusCode): $message';
}

@immutable
/// Session token used to group autocomplete and details requests.
///
/// Google recommends reusing a session token across the autocomplete flow and
/// the final place-details resolution for the selected result.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/place-session-tokens
class AutocompleteSessionToken {
  const AutocompleteSessionToken._(this.value);

  final String value;

  factory AutocompleteSessionToken.generate() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return AutocompleteSessionToken._(buffer.toString());
  }

  factory AutocompleteSessionToken.fromValue(String value) =>
      AutocompleteSessionToken._(value);

  @override
  String toString() => value;
}

@immutable
/// Latitude/longitude pair used in places requests and responses.
class PlaceCoordinates {
  const PlaceCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => <String, Object?>{
    'latitude': latitude,
    'longitude': longitude,
  };

  Map<String, Object?> toWebJson() => <String, Object?>{
    'lat': latitude,
    'lng': longitude,
  };

  factory PlaceCoordinates.fromJson(Map<String, Object?> json) {
    return PlaceCoordinates(
      latitude: _toDouble(json['latitude'] ?? json['lat']) ?? 0,
      longitude: _toDouble(json['longitude'] ?? json['lng']) ?? 0,
    );
  }
}

@immutable
/// Geographic viewport returned by Google for a place.
class PlaceViewport {
  const PlaceViewport({required this.northeast, required this.southwest});

  final PlaceCoordinates northeast;
  final PlaceCoordinates southwest;

  Map<String, Object?> toJson() => <String, Object?>{
    'northeast': northeast.toJson(),
    'southwest': southwest.toJson(),
  };
}

@immutable
/// Base type for circle and rectangle location constraints.
sealed class PlacesArea {
  const PlacesArea();

  Map<String, Object?> toRestJson();

  Map<String, Object?> toWebJson();
}

@immutable
/// Circular location constraint or bias.
class CircleArea extends PlacesArea {
  const CircleArea({required this.center, required this.radiusMeters});

  final PlaceCoordinates center;
  final double radiusMeters;

  @override
  Map<String, Object?> toRestJson() => <String, Object?>{
    'circle': <String, Object?>{
      'center': center.toJson(),
      'radius': radiusMeters,
    },
  };

  @override
  Map<String, Object?> toWebJson() => <String, Object?>{
    'center': center.toWebJson(),
    'radius': radiusMeters,
  };
}

@immutable
/// Rectangular location constraint or bias.
class RectangleArea extends PlacesArea {
  const RectangleArea({required this.low, required this.high});

  final PlaceCoordinates low;
  final PlaceCoordinates high;

  @override
  Map<String, Object?> toRestJson() => <String, Object?>{
    'rectangle': <String, Object?>{'low': low.toJson(), 'high': high.toJson()},
  };

  @override
  Map<String, Object?> toWebJson() => <String, Object?>{
    'south': low.latitude,
    'west': low.longitude,
    'north': high.latitude,
    'east': high.longitude,
  };
}

@immutable
/// Soft geographic preference for autocomplete and text search.
///
/// Use this when results should be biased toward an area without strictly
/// excluding results outside it.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete#locationBias
class LocationBias {
  const LocationBias._(this.area);

  final PlacesArea area;

  factory LocationBias.circle({
    required PlaceCoordinates center,
    required double radiusMeters,
  }) => LocationBias._(CircleArea(center: center, radiusMeters: radiusMeters));

  factory LocationBias.rectangle({
    required PlaceCoordinates low,
    required PlaceCoordinates high,
  }) => LocationBias._(RectangleArea(low: low, high: high));
}

@immutable
/// Hard geographic restriction for autocomplete and search results.
///
/// Use this when results must fall inside the specified area.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete#locationRestriction
class LocationRestriction {
  const LocationRestriction._(this.area);

  final PlacesArea area;

  factory LocationRestriction.circle({
    required PlaceCoordinates center,
    required double radiusMeters,
  }) => LocationRestriction._(
    CircleArea(center: center, radiusMeters: radiusMeters),
  );

  factory LocationRestriction.rectangle({
    required PlaceCoordinates low,
    required PlaceCoordinates high,
  }) => LocationRestriction._(RectangleArea(low: low, high: high));
}

/// Field-mask entries supported by Places API (New) details and search calls.
///
/// These values map directly to Google’s field-mask names. Use them when
/// choosing [PlaceDetailsRequest.fields] or one of the `search` request field
/// sets.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/place-details#fields
enum PlaceField {
  id('id'),
  name('name'),
  displayName('displayName'),
  formattedAddress('formattedAddress'),
  shortFormattedAddress('shortFormattedAddress'),
  adrFormatAddress('adrFormatAddress'),
  location('location'),
  viewport('viewport'),
  types('types'),
  primaryType('primaryType'),
  primaryTypeDisplayName('primaryTypeDisplayName'),
  businessStatus('businessStatus'),
  googleMapsUri('googleMapsUri'),
  websiteUri('websiteUri'),
  nationalPhoneNumber('nationalPhoneNumber'),
  internationalPhoneNumber('internationalPhoneNumber'),
  rating('rating'),
  userRatingCount('userRatingCount'),
  priceLevel('priceLevel'),
  plusCode('plusCode'),
  iconMaskBaseUri('iconMaskBaseUri'),
  iconBackgroundColor('iconBackgroundColor'),
  utcOffsetMinutes('utcOffsetMinutes'),
  currentOpeningHours('currentOpeningHours'),
  regularOpeningHours('regularOpeningHours'),
  currentSecondaryOpeningHours('currentSecondaryOpeningHours'),
  regularSecondaryOpeningHours('regularSecondaryOpeningHours'),
  photos('photos'),
  reviews('reviews'),
  addressComponents('addressComponents'),
  delivery('delivery'),
  dineIn('dineIn'),
  takeout('takeout'),
  reservable('reservable'),
  servesBreakfast('servesBreakfast'),
  servesLunch('servesLunch'),
  servesDinner('servesDinner'),
  servesBeer('servesBeer'),
  servesWine('servesWine'),
  servesDessert('servesDessert'),
  servesCoffee('servesCoffee'),
  outdoorSeating('outdoorSeating'),
  restroom('restroom'),
  goodForChildren('goodForChildren'),
  goodForGroups('goodForGroups'),
  paymentOptions('paymentOptions'),
  parkingOptions('parkingOptions'),
  accessibilityOptions('accessibilityOptions');

  const PlaceField(this.apiName);

  /// Google Places API field-mask name for this field.
  final String apiName;

  /// Field-mask entry used by Google search endpoints.
  String get searchMaskPath => 'places.$apiName';
}

/// Curated field-mask presets for fetching place details and search results.
abstract final class PlaceFieldPresets {
  /// Small payload suitable for basic display and coordinates.
  static const Set<PlaceField> minimal = <PlaceField>{
    PlaceField.id,
    PlaceField.displayName,
    PlaceField.formattedAddress,
    PlaceField.location,
  };

  /// Balanced default payload for common product usage.
  static const Set<PlaceField> recommended = <PlaceField>{
    ...minimal,
    PlaceField.primaryType,
    PlaceField.primaryTypeDisplayName,
    PlaceField.googleMapsUri,
    PlaceField.rating,
    PlaceField.userRatingCount,
    PlaceField.iconMaskBaseUri,
    PlaceField.iconBackgroundColor,
  };

  /// Rich payload with additional business, review, and amenity data.
  static const Set<PlaceField> rich = <PlaceField>{
    ...recommended,
    PlaceField.websiteUri,
    PlaceField.nationalPhoneNumber,
    PlaceField.internationalPhoneNumber,
    PlaceField.viewport,
    PlaceField.businessStatus,
    PlaceField.priceLevel,
    PlaceField.regularOpeningHours,
    PlaceField.currentOpeningHours,
    PlaceField.photos,
    PlaceField.reviews,
    PlaceField.delivery,
    PlaceField.dineIn,
    PlaceField.takeout,
    PlaceField.reservable,
    PlaceField.servesBreakfast,
    PlaceField.servesLunch,
    PlaceField.servesDinner,
    PlaceField.servesBeer,
    PlaceField.servesWine,
    PlaceField.servesDessert,
    PlaceField.servesCoffee,
    PlaceField.outdoorSeating,
    PlaceField.restroom,
    PlaceField.goodForChildren,
    PlaceField.goodForGroups,
    PlaceField.paymentOptions,
    PlaceField.parkingOptions,
    PlaceField.accessibilityOptions,
  };
}

/// Ranking preference for text search.
enum SearchByTextRankPreference {
  relevance('RELEVANCE'),
  distance('DISTANCE');

  const SearchByTextRankPreference(this.restName);

  final String restName;
}

/// Ranking preference for nearby search.
enum SearchNearbyRankPreference {
  popularity('POPULARITY'),
  distance('DISTANCE');

  const SearchNearbyRankPreference(this.restName);

  final String restName;
}

@immutable
/// Text value returned by Google with an optional language code.
class LocalizedText {
  const LocalizedText({required this.text, this.languageCode});

  final String text;
  final String? languageCode;

  factory LocalizedText.fromJson(Object? source) {
    if (source is String) {
      return LocalizedText(text: source);
    }
    final json = (source as Map?)?.cast<String, Object?>();
    return LocalizedText(
      text: (json?['text'] ?? '') as String,
      languageCode: json?['languageCode'] as String?,
    );
  }
}

@immutable
/// Match offsets inside a structured text fragment.
class TextMatch {
  const TextMatch({required this.startOffset, required this.endOffset});

  final int startOffset;
  final int endOffset;
}

@immutable
/// Text plus match ranges returned by Google structured formatting.
class StructuredText {
  const StructuredText({
    required this.text,
    this.matches = const <TextMatch>[],
  });

  final String text;
  final List<TextMatch> matches;

  factory StructuredText.fromJson(Object? source) {
    if (source is String) {
      return StructuredText(text: source);
    }
    final json = (source as Map?)?.cast<String, Object?>();
    final matches = ((json?['matches'] as List?) ?? <Object?>[])
        .map((match) => (match as Map).cast<String, Object?>())
        .map(
          (match) => TextMatch(
            startOffset: (match['startOffset'] as num?)?.toInt() ?? 0,
            endOffset:
                (match['endOffset'] as num?)?.toInt() ??
                (((match['startOffset'] as num?)?.toInt() ?? 0) + 1),
          ),
        )
        .toList(growable: false);
    return StructuredText(
      text: (json?['text'] ?? '') as String,
      matches: matches,
    );
  }
}

@immutable
/// Lightweight autocomplete suggestion returned by Places API (New).
class PlaceSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.placeResourceName,
    required this.fullText,
    required this.primaryText,
    this.secondaryText,
    this.distanceMeters,
    this.types = const <String>[],
    this.rawData = const <String, Object?>{},
  });

  /// Stable Google place id for the suggested place.
  final String placeId;

  /// Full Google resource name, such as `places/ChIJ...`.
  final String placeResourceName;

  /// Full display text returned by Google for this suggestion.
  final StructuredText fullText;

  /// Primary display text, typically the place name.
  final StructuredText primaryText;

  /// Secondary display text, typically address or locality context.
  final StructuredText? secondaryText;

  /// Distance from the request origin, when Google includes it.
  final int? distanceMeters;

  /// Place types returned for this suggestion.
  final List<String> types;

  /// Raw suggestion payload from Google.
  final Map<String, Object?> rawData;

  /// Plain text value of [fullText].
  String get displayText => fullText.text;

  factory PlaceSuggestion.fromRestJson(Map<String, Object?> json) {
    final prediction =
        (json['placePrediction'] as Map?)?.cast<String, Object?>() ?? json;
    final structuredFormat = (prediction['structuredFormat'] as Map?)
        ?.cast<String, Object?>();

    return PlaceSuggestion(
      placeId: (prediction['placeId'] ?? '') as String,
      placeResourceName: (prediction['place'] ?? '') as String,
      fullText: StructuredText.fromJson(prediction['text']),
      primaryText: StructuredText.fromJson(
        structuredFormat?['mainText'] ?? prediction['text'],
      ),
      secondaryText: structuredFormat?['secondaryText'] == null
          ? null
          : StructuredText.fromJson(structuredFormat?['secondaryText']),
      distanceMeters: (prediction['distanceMeters'] as num?)?.toInt(),
      types: ((prediction['types'] as List?) ?? <Object?>[])
          .whereType<String>()
          .toList(growable: false),
      rawData: Map<String, Object?>.unmodifiable(prediction),
    );
  }
}

@immutable
/// Time zone metadata returned by Google Time Zone API.
///
/// This data is fetched separately from Places API using the selected place
/// coordinates.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/timezone/requests-timezone
class PlaceTimeZoneData {
  const PlaceTimeZoneData({
    required this.dstOffset,
    required this.rawOffset,
    required this.timeZoneId,
    required this.timeZoneName,
    required this.timestamp,
    this.rawData = const <String, Object?>{},
  });

  /// Daylight saving offset for the supplied [timestamp].
  final Duration dstOffset;

  /// Base UTC offset for the supplied [timestamp], excluding DST.
  final Duration rawOffset;

  /// Stable Google/Olson time-zone id, such as `America/New_York`.
  final String timeZoneId;

  /// Human-readable time-zone name, such as `Eastern Daylight Time`.
  final String timeZoneName;

  /// Timestamp used for this time-zone lookup.
  final DateTime timestamp;

  /// Full raw payload from Google.
  final Map<String, Object?> rawData;

  factory PlaceTimeZoneData.fromJson(
    Map<String, Object?> json, {
    required DateTime timestamp,
  }) => PlaceTimeZoneData(
    dstOffset: Duration(
      milliseconds: (((_toDouble(json['dstOffset']) ?? 0) * 1000).round()),
    ),
    rawOffset: Duration(
      milliseconds: (((_toDouble(json['rawOffset']) ?? 0) * 1000).round()),
    ),
    timeZoneId: (json['timeZoneId'] ?? '') as String,
    timeZoneName: (json['timeZoneName'] ?? '') as String,
    timestamp: timestamp,
    rawData: Map<String, Object?>.unmodifiable(json),
  );
}

@immutable
/// Unified selection result returned by field and overlay flows.
///
/// Always contains the selected [suggestion]. When details fetching is enabled,
/// [place] may also be populated. When time-zone fetching is enabled,
/// [timeZone] may also be populated.
class PlaceSelection {
  const PlaceSelection({required this.suggestion, this.place, this.timeZone});

  /// The lightweight autocomplete suggestion the user selected.
  final PlaceSuggestion suggestion;

  /// Rich place details resolved for the selection, if requested.
  final PlaceData? place;

  /// Time-zone data resolved for the selection, if requested.
  final PlaceTimeZoneData? timeZone;

  /// Convenience getter for [suggestion.placeId].
  String get placeId => suggestion.placeId;

  /// Convenience getter for [suggestion.displayText].
  String get displayText => suggestion.displayText;

  /// Whether [place] is available.
  bool get hasResolvedPlace => place != null;

  /// Whether [timeZone] is available.
  bool get hasTimeZone => timeZone != null;

  PlaceSelection copyWith({
    PlaceSuggestion? suggestion,
    PlaceData? place,
    PlaceTimeZoneData? timeZone,
  }) {
    return PlaceSelection(
      suggestion: suggestion ?? this.suggestion,
      place: place ?? this.place,
      timeZone: timeZone ?? this.timeZone,
    );
  }
}

@immutable
/// Photo metadata returned in rich place details.
class PlacePhoto {
  const PlacePhoto({
    required this.name,
    this.widthPx,
    this.heightPx,
    this.googleMapsUri,
    this.authorAttributions = const <Map<String, Object?>>[],
  });

  final String name;
  final int? widthPx;
  final int? heightPx;
  final String? googleMapsUri;
  final List<Map<String, Object?>> authorAttributions;

  factory PlacePhoto.fromJson(Map<String, Object?> json) => PlacePhoto(
    name: (json['name'] ?? '') as String,
    widthPx: (json['widthPx'] as num?)?.toInt(),
    heightPx: (json['heightPx'] as num?)?.toInt(),
    googleMapsUri: json['googleMapsUri'] as String?,
    authorAttributions: ((json['authorAttributions'] as List?) ?? <Object?>[])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false),
  );
}

@immutable
/// Review metadata returned in rich place details.
class PlaceReview {
  const PlaceReview({
    required this.authorName,
    required this.text,
    this.rating,
    this.relativePublishTimeDescription,
    this.googleMapsUri,
    this.originalText,
  });

  final String authorName;
  final LocalizedText text;
  final double? rating;
  final String? relativePublishTimeDescription;
  final String? googleMapsUri;
  final LocalizedText? originalText;

  factory PlaceReview.fromJson(Map<String, Object?> json) {
    final authorAttribution = (json['authorAttribution'] as Map?)
        ?.cast<String, Object?>();
    return PlaceReview(
      authorName: (authorAttribution?['displayName'] ?? '') as String,
      text: LocalizedText.fromJson(json['text']),
      rating: _toDouble(json['rating']),
      relativePublishTimeDescription:
          json['relativePublishTimeDescription'] as String?,
      googleMapsUri: json['googleMapsUri'] as String?,
      originalText: json['originalText'] == null
          ? null
          : LocalizedText.fromJson(json['originalText']),
    );
  }
}

@immutable
/// Rich place details returned by Places API (New).
class PlaceData {
  const PlaceData({
    required this.id,
    this.resourceName,
    this.displayName,
    this.formattedAddress,
    this.shortFormattedAddress,
    this.location,
    this.viewport,
    this.types = const <String>[],
    this.primaryType,
    this.primaryTypeDisplayName,
    this.googleMapsUri,
    this.websiteUri,
    this.nationalPhoneNumber,
    this.internationalPhoneNumber,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.businessStatus,
    this.iconMaskBaseUri,
    this.iconBackgroundColor,
    this.utcOffsetMinutes,
    this.delivery,
    this.dineIn,
    this.takeout,
    this.reservable,
    this.servesBreakfast,
    this.servesLunch,
    this.servesDinner,
    this.servesBeer,
    this.servesWine,
    this.servesDessert,
    this.servesCoffee,
    this.outdoorSeating,
    this.restroom,
    this.goodForChildren,
    this.goodForGroups,
    this.currentOpeningHours,
    this.regularOpeningHours,
    this.reviews = const <PlaceReview>[],
    this.photos = const <PlacePhoto>[],
    this.rawData = const <String, Object?>{},
  });

  /// Stable Google place id.
  final String id;

  /// Full Google resource name, such as `places/ChIJ...`.
  final String? resourceName;

  /// Human-readable place name.
  final LocalizedText? displayName;

  /// Full formatted address returned by Google.
  final String? formattedAddress;

  /// Short formatted address returned by Google.
  final String? shortFormattedAddress;

  /// Geographic coordinates for the place.
  final PlaceCoordinates? location;

  /// Geographic viewport associated with the place.
  final PlaceViewport? viewport;

  /// Types returned by Google for this place.
  final List<String> types;

  /// Google primary type for this place.
  final String? primaryType;

  /// Localized display text for the primary type.
  final LocalizedText? primaryTypeDisplayName;
  final String? googleMapsUri;
  final String? websiteUri;
  final String? nationalPhoneNumber;
  final String? internationalPhoneNumber;
  final double? rating;
  final int? userRatingCount;
  final String? priceLevel;
  final String? businessStatus;
  final String? iconMaskBaseUri;
  final String? iconBackgroundColor;
  final int? utcOffsetMinutes;
  final bool? delivery;
  final bool? dineIn;
  final bool? takeout;
  final bool? reservable;
  final bool? servesBreakfast;
  final bool? servesLunch;
  final bool? servesDinner;
  final bool? servesBeer;
  final bool? servesWine;
  final bool? servesDessert;
  final bool? servesCoffee;
  final bool? outdoorSeating;
  final bool? restroom;
  final bool? goodForChildren;
  final bool? goodForGroups;
  final Map<String, Object?>? currentOpeningHours;
  final Map<String, Object?>? regularOpeningHours;

  /// Reviews returned when review fields are requested.
  final List<PlaceReview> reviews;

  /// Photos returned when photo fields are requested.
  final List<PlacePhoto> photos;

  /// Full raw payload from Google.
  final Map<String, Object?> rawData;

  factory PlaceData.fromJson(Map<String, Object?> json) => PlaceData(
    id: (json['id'] ?? '') as String,
    resourceName: json['name'] as String?,
    displayName: json['displayName'] == null
        ? null
        : LocalizedText.fromJson(json['displayName']),
    formattedAddress: json['formattedAddress'] as String?,
    shortFormattedAddress: json['shortFormattedAddress'] as String?,
    location: _parseCoordinates(json['location']),
    viewport: _parseViewport(json['viewport']),
    types: ((json['types'] as List?) ?? <Object?>[]).whereType<String>().toList(
      growable: false,
    ),
    primaryType: json['primaryType'] as String?,
    primaryTypeDisplayName: json['primaryTypeDisplayName'] == null
        ? null
        : LocalizedText.fromJson(json['primaryTypeDisplayName']),
    googleMapsUri: json['googleMapsUri'] as String?,
    websiteUri: json['websiteUri'] as String?,
    nationalPhoneNumber: json['nationalPhoneNumber'] as String?,
    internationalPhoneNumber: json['internationalPhoneNumber'] as String?,
    rating: _toDouble(json['rating']),
    userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
    priceLevel: json['priceLevel'] as String?,
    businessStatus: json['businessStatus'] as String?,
    iconMaskBaseUri: json['iconMaskBaseUri'] as String?,
    iconBackgroundColor: json['iconBackgroundColor'] as String?,
    utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt(),
    delivery: json['delivery'] as bool?,
    dineIn: json['dineIn'] as bool?,
    takeout: json['takeout'] as bool?,
    reservable: json['reservable'] as bool?,
    servesBreakfast: json['servesBreakfast'] as bool?,
    servesLunch: json['servesLunch'] as bool?,
    servesDinner: json['servesDinner'] as bool?,
    servesBeer: json['servesBeer'] as bool?,
    servesWine: json['servesWine'] as bool?,
    servesDessert: json['servesDessert'] as bool?,
    servesCoffee: json['servesCoffee'] as bool?,
    outdoorSeating: json['outdoorSeating'] as bool?,
    restroom: json['restroom'] as bool?,
    goodForChildren: json['goodForChildren'] as bool?,
    goodForGroups: json['goodForGroups'] as bool?,
    currentOpeningHours: (json['currentOpeningHours'] as Map?)
        ?.cast<String, Object?>(),
    regularOpeningHours: (json['regularOpeningHours'] as Map?)
        ?.cast<String, Object?>(),
    reviews: ((json['reviews'] as List?) ?? <Object?>[])
        .whereType<Map>()
        .map((review) => PlaceReview.fromJson(review.cast<String, Object?>()))
        .toList(growable: false),
    photos: ((json['photos'] as List?) ?? <Object?>[])
        .whereType<Map>()
        .map((photo) => PlacePhoto.fromJson(photo.cast<String, Object?>()))
        .toList(growable: false),
    rawData: Map<String, Object?>.unmodifiable(json),
  );
}

/// Request payload for Places API (New) autocomplete.
///
/// The request shape intentionally follows the new Google Places terminology,
/// including [languageCode], [regionCode], [locationBias],
/// [locationRestriction], and [includedPrimaryTypes].
///
/// Example:
/// ```dart
/// const request = AutocompleteRequest(
///   input: 'coffee',
///   languageCode: 'en',
///   regionCode: 'us',
///   includedPrimaryTypes: <String>['cafe'],
/// );
/// ```
///
/// Google documentation:
/// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete
@immutable
class AutocompleteRequest {
  const AutocompleteRequest({
    required this.input,
    this.sessionToken,
    this.languageCode,
    this.regionCode,
    this.inputOffset,
    this.origin,
    this.locationBias,
    this.locationRestriction,
    this.includedPrimaryTypes = const <String>[],
    this.includedRegionCodes = const <String>[],
    this.includePureServiceAreaBusinesses = false,
  });

  final String input;
  final AutocompleteSessionToken? sessionToken;
  final String? languageCode;
  final String? regionCode;
  final int? inputOffset;
  final PlaceCoordinates? origin;
  final LocationBias? locationBias;
  final LocationRestriction? locationRestriction;

  /// Restricts autocomplete results to places whose primary type matches one
  /// of these values.
  ///
  /// This maps directly to Google Places API (New)
  /// `includedPrimaryTypes`. Google allows up to five values from its supported
  /// place-type tables, or only `(regions)`, or only `(cities)`.
  ///
  /// Examples:
  /// ```dart
  /// includedPrimaryTypes: <String>['restaurant']
  /// includedPrimaryTypes: <String>['cafe', 'bakery']
  /// includedPrimaryTypes: <String>['(cities)']
  /// ```
  ///
  /// Keep these values as raw strings because Google’s supported type list is
  /// large and may evolve over time.
  ///
  /// Official reference:
  /// https://developers.google.com/maps/documentation/places/web-service/place-autocomplete#includedPrimaryTypes
  final List<String> includedPrimaryTypes;

  /// Restricts autocomplete results to the supplied CLDR region codes.
  ///
  /// Example:
  /// ```dart
  /// includedRegionCodes: <String>['us', 'ca']
  /// ```
  final List<String> includedRegionCodes;

  /// Whether pure service-area businesses should be included in results.
  final bool includePureServiceAreaBusinesses;

  void validate() {
    if (input.trim().isEmpty) {
      throw const PlacesException('Autocomplete input cannot be empty.');
    }
    if (locationBias != null && locationRestriction != null) {
      throw const PlacesException(
        'locationBias and locationRestriction cannot be set together.',
      );
    }
  }

  Map<String, Object?> toRestJson() {
    validate();
    return <String, Object?>{
      'input': input,
      if (sessionToken != null) 'sessionToken': sessionToken!.value,
      if (languageCode != null) 'languageCode': languageCode,
      if (regionCode != null) 'regionCode': regionCode,
      if (inputOffset != null) 'inputOffset': inputOffset,
      if (origin != null) 'origin': origin!.toJson(),
      if (locationBias != null) 'locationBias': locationBias!.area.toRestJson(),
      if (locationRestriction != null)
        'locationRestriction': locationRestriction!.area.toRestJson(),
      if (includedPrimaryTypes.isNotEmpty)
        'includedPrimaryTypes': includedPrimaryTypes,
      if (includedRegionCodes.isNotEmpty)
        'includedRegionCodes': includedRegionCodes,
      'includePureServiceAreaBusinesses': includePureServiceAreaBusinesses,
    };
  }
}

@immutable
/// Request payload for Place Details (New).
class PlaceDetailsRequest {
  const PlaceDetailsRequest({
    required this.placeId,
    this.fields = PlaceFieldPresets.recommended,
    this.languageCode,
    this.regionCode,
    this.sessionToken,
  });

  /// Place id to resolve.
  final String placeId;

  /// Fields to request from Google.
  final Set<PlaceField> fields;

  /// Preferred BCP-47 language code for the response.
  final String? languageCode;

  /// Preferred CLDR region code for the response.
  final String? regionCode;

  /// Optional autocomplete session token associated with this place lookup.
  final AutocompleteSessionToken? sessionToken;

  /// Comma-separated field mask for Google Place Details requests.
  String get detailsFieldMask => fields.map((field) => field.apiName).join(',');
}

@immutable
/// Request payload for Google Time Zone API.
///
/// Time-zone lookups are based on geographic coordinates and a timestamp.
/// If [timestamp] is omitted, callers typically use the current time.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/timezone/requests-timezone
class TimeZoneRequest {
  const TimeZoneRequest({
    required this.location,
    this.timestamp,
    this.languageCode,
  });

  /// Geographic coordinates to resolve into time-zone metadata.
  final PlaceCoordinates location;

  /// Timestamp the time-zone lookup should apply to.
  ///
  /// If omitted, the client/backend should default to the current time.
  final DateTime? timestamp;

  /// Optional BCP-47 language code for localized time-zone names.
  final String? languageCode;

  /// Creates a time-zone request from resolved place details.
  ///
  /// Throws [PlacesException] if [place] does not include [PlaceData.location].
  factory TimeZoneRequest.fromPlace(
    PlaceData place, {
    DateTime? timestamp,
    String? languageCode,
  }) {
    final location = place.location;
    if (location == null) {
      throw const PlacesException(
        'Time zone lookup requires place details with location coordinates.',
      );
    }
    return TimeZoneRequest(
      location: location,
      timestamp: timestamp,
      languageCode: languageCode,
    );
  }
}

@immutable
/// Request payload for Text Search (New).
class TextSearchRequest {
  const TextSearchRequest({
    required this.textQuery,
    this.fields = PlaceFieldPresets.recommended,
    this.languageCode,
    this.regionCode,
    this.includedType,
    this.strictTypeFiltering = false,
    this.locationBias,
    this.locationRestriction,
    this.maxResultCount,
    this.minRating,
    this.openNow,
    this.rankPreference = SearchByTextRankPreference.relevance,
  });

  /// Free-text search query.
  final String textQuery;

  /// Fields to request for each result.
  final Set<PlaceField> fields;

  /// Preferred BCP-47 language code for the response.
  final String? languageCode;

  /// Preferred CLDR region code for the response.
  final String? regionCode;

  /// Optional type filter for text search.
  final String? includedType;

  /// Whether [includedType] should be applied strictly.
  final bool strictTypeFiltering;
  final LocationBias? locationBias;
  final LocationRestriction? locationRestriction;
  final int? maxResultCount;
  final double? minRating;
  final bool? openNow;
  final SearchByTextRankPreference rankPreference;

  /// Validates request invariants before serialization.
  ///
  /// Throws [PlacesException] if [textQuery] is empty or if both
  /// [locationBias] and [locationRestriction] are set.
  void validate() {
    if (textQuery.trim().isEmpty) {
      throw const PlacesException('Text search query cannot be empty.');
    }
    if (locationBias != null && locationRestriction != null) {
      throw const PlacesException(
        'locationBias and locationRestriction cannot be set together.',
      );
    }
  }

  /// Field mask used for text search requests.
  String get searchFieldMask =>
      fields.map((field) => field.searchMaskPath).join(',');

  Map<String, Object?> toRestJson() {
    validate();
    return <String, Object?>{
      'textQuery': textQuery,
      if (languageCode != null) 'languageCode': languageCode,
      if (regionCode != null) 'regionCode': regionCode,
      if (includedType != null) 'includedType': includedType,
      'strictTypeFiltering': strictTypeFiltering,
      if (locationBias != null) 'locationBias': locationBias!.area.toRestJson(),
      if (locationRestriction != null)
        'locationRestriction': locationRestriction!.area.toRestJson(),
      if (maxResultCount != null) 'maxResultCount': maxResultCount,
      if (minRating != null) 'minRating': minRating,
      if (openNow != null) 'openNow': openNow,
      'rankPreference': rankPreference.restName,
    };
  }
}

@immutable
/// Request payload for Nearby Search (New).
class NearbySearchRequest {
  const NearbySearchRequest({
    required this.locationRestriction,
    this.fields = PlaceFieldPresets.recommended,
    this.languageCode,
    this.regionCode,
    this.includedTypes = const <String>[],
    this.excludedTypes = const <String>[],
    this.includedPrimaryTypes = const <String>[],
    this.excludedPrimaryTypes = const <String>[],
    this.maxResultCount,
    this.rankPreference = SearchNearbyRankPreference.popularity,
  });

  /// Required geographic restriction for nearby search.
  final LocationRestriction locationRestriction;

  /// Fields to request for each result.
  final Set<PlaceField> fields;

  /// Preferred BCP-47 language code for the response.
  final String? languageCode;

  /// Preferred CLDR region code for the response.
  final String? regionCode;

  /// Included Google place types.
  final List<String> includedTypes;

  /// Excluded Google place types.
  final List<String> excludedTypes;

  /// Included Google primary place types.
  final List<String> includedPrimaryTypes;

  /// Excluded Google primary place types.
  final List<String> excludedPrimaryTypes;

  /// Maximum result count, when supported by Google.
  final int? maxResultCount;

  /// Ranking behavior for nearby results.
  final SearchNearbyRankPreference rankPreference;

  /// Field mask used for nearby search requests.
  String get searchFieldMask =>
      fields.map((field) => field.searchMaskPath).join(',');

  Map<String, Object?> toRestJson() => <String, Object?>{
    'locationRestriction': locationRestriction.area.toRestJson(),
    if (languageCode != null) 'languageCode': languageCode,
    if (regionCode != null) 'regionCode': regionCode,
    if (includedTypes.isNotEmpty) 'includedTypes': includedTypes,
    if (excludedTypes.isNotEmpty) 'excludedTypes': excludedTypes,
    if (includedPrimaryTypes.isNotEmpty)
      'includedPrimaryTypes': includedPrimaryTypes,
    if (excludedPrimaryTypes.isNotEmpty)
      'excludedPrimaryTypes': excludedPrimaryTypes,
    if (maxResultCount != null) 'maxResultCount': maxResultCount,
    'rankPreference': rankPreference.restName,
  };
}

double? _toDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

PlaceCoordinates? _parseCoordinates(Object? source) {
  if (source == null) {
    return null;
  }
  final json = (source as Map).cast<String, Object?>();
  return PlaceCoordinates(
    latitude: _toDouble(json['latitude'] ?? json['lat']) ?? 0,
    longitude: _toDouble(json['longitude'] ?? json['lng']) ?? 0,
  );
}

PlaceViewport? _parseViewport(Object? source) {
  if (source == null) {
    return null;
  }
  final json = (source as Map).cast<String, Object?>();
  final northeast = _parseCoordinates(json['northeast'] ?? json['high']);
  final southwest = _parseCoordinates(json['southwest'] ?? json['low']);
  if (northeast == null || southwest == null) {
    return null;
  }
  return PlaceViewport(northeast: northeast, southwest: southwest);
}

String prettyJson(Map<String, Object?> value) =>
    const JsonEncoder.withIndent('  ').convert(value);
