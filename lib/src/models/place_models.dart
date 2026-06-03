import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

@immutable
/// Exception thrown for invalid requests or Places API failures.
class PlacesException implements Exception {
  /// Creates an exception representing a request validation or API failure.
  const PlacesException(this.message, {this.statusCode, this.details});

  /// Human-readable description of the failure.
  final String message;

  /// Optional HTTP status code when the error came from a network request.
  final int? statusCode;

  /// Optional structured details returned by Google.
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
  /// Creates a session token from an already-generated token value.
  const AutocompleteSessionToken._(this.value);

  /// Raw token value sent to Google.
  final String value;

  /// Generates a new random session token.
  factory AutocompleteSessionToken.generate() {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < 32; i++) {
      buffer.write(random.nextInt(16).toRadixString(16));
    }
    return AutocompleteSessionToken._(buffer.toString());
  }

  /// Rehydrates a session token from an existing raw value.
  factory AutocompleteSessionToken.fromValue(String value) =>
      AutocompleteSessionToken._(value);

  @override
  String toString() => value;
}

@immutable
/// Latitude/longitude pair used in places requests and responses.
class PlaceCoordinates {
  /// Creates a geographic coordinate pair.
  const PlaceCoordinates({required this.latitude, required this.longitude});

  /// Latitude in decimal degrees.
  final double latitude;

  /// Longitude in decimal degrees.
  final double longitude;

  /// Serializes coordinates using the Places HTTP API field names.
  Map<String, Object?> toJson() => <String, Object?>{
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Serializes coordinates using the Maps JavaScript API field names.
  Map<String, Object?> toWebJson() => <String, Object?>{
    'lat': latitude,
    'lng': longitude,
  };

  /// Parses coordinates from either HTTP or Maps JavaScript payloads.
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
  /// Creates a rectangular viewport for a place.
  const PlaceViewport({required this.northeast, required this.southwest});

  /// Northeast corner of the viewport.
  final PlaceCoordinates northeast;

  /// Southwest corner of the viewport.
  final PlaceCoordinates southwest;

  /// Serializes the viewport to a JSON-compatible map.
  Map<String, Object?> toJson() => <String, Object?>{
    'northeast': northeast.toJson(),
    'southwest': southwest.toJson(),
  };
}

@immutable
/// Base type for circle and rectangle location constraints.
sealed class PlacesArea {
  /// Base constructor for a geographic bias or restriction area.
  const PlacesArea();

  /// Serializes the area for Places HTTP API requests.
  Map<String, Object?> toRestJson();

  /// Serializes the area for Maps JavaScript API requests.
  Map<String, Object?> toWebJson();
}

@immutable
/// Circular location constraint or bias.
class CircleArea extends PlacesArea {
  /// Creates a circular bias or restriction area.
  const CircleArea({required this.center, required this.radiusMeters});

  /// Center of the circle.
  final PlaceCoordinates center;

  /// Circle radius in meters.
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
  /// Creates a rectangular bias or restriction area.
  const RectangleArea({required this.low, required this.high});

  /// Lower-left / southwest coordinate.
  final PlaceCoordinates low;

  /// Upper-right / northeast coordinate.
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
  /// Creates a location bias from a concrete [PlacesArea].
  const LocationBias._(this.area);

  /// Area used to bias, but not strictly limit, results.
  final PlacesArea area;

  /// Creates a circular location bias.
  factory LocationBias.circle({
    required PlaceCoordinates center,
    required double radiusMeters,
  }) => LocationBias._(CircleArea(center: center, radiusMeters: radiusMeters));

  /// Creates a rectangular location bias.
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
  /// Creates a location restriction from a concrete [PlacesArea].
  const LocationRestriction._(this.area);

  /// Area used to strictly restrict results.
  final PlacesArea area;

  /// Creates a circular location restriction.
  factory LocationRestriction.circle({
    required PlaceCoordinates center,
    required double radiusMeters,
  }) => LocationRestriction._(
    CircleArea(center: center, radiusMeters: radiusMeters),
  );

  /// Creates a rectangular location restriction.
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
  postalAddress('postalAddress'),
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
  accessibilityOptions('accessibilityOptions'),
  addressDescriptor('addressDescriptor'),
  evChargeOptions('evChargeOptions'),
  fuelOptions('fuelOptions'),
  generativeSummary('generativeSummary'),
  pureServiceAreaBusiness('pureServiceAreaBusiness'),
  movedPlace('movedPlace'),
  movedPlaceId('movedPlaceId');

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
    PlaceField.postalAddress,
    PlaceField.addressComponents,
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

  /// Raw enum value expected by the Places text search API.
  final String restName;
}

/// Ranking preference for nearby search.
enum SearchNearbyRankPreference {
  popularity('POPULARITY'),
  distance('DISTANCE');

  const SearchNearbyRankPreference(this.restName);

  /// Raw enum value expected by the Places nearby search API.
  final String restName;
}

@immutable
/// Text value returned by Google with an optional language code.
class LocalizedText {
  /// Creates a localized text value.
  const LocalizedText({required this.text, this.languageCode});

  /// Text content returned by Google.
  final String text;

  /// Optional BCP-47 language code for [text].
  final String? languageCode;

  factory LocalizedText.fromJson(Object? source) {
    if (source is String) {
      return LocalizedText(text: source);
    }
    final json = (source as Map<Object?, Object?>?)?.cast<String, Object?>();
    return LocalizedText(
      text: (json?['text'] ?? '') as String,
      languageCode: json?['languageCode'] as String?,
    );
  }
}

@immutable
/// Match offsets inside a structured text fragment.
class TextMatch {
  /// Creates a structured-text match range.
  const TextMatch({required this.startOffset, required this.endOffset});

  /// Inclusive match start offset.
  final int startOffset;

  /// Exclusive match end offset.
  final int endOffset;
}

@immutable
/// Text plus match ranges returned by Google structured formatting.
class StructuredText {
  /// Creates a structured text fragment with optional highlight ranges.
  const StructuredText({
    required this.text,
    this.matches = const <TextMatch>[],
  });

  /// Text content returned by Google.
  final String text;

  /// Highlight ranges inside [text].
  final List<TextMatch> matches;

  factory StructuredText.fromJson(Object? source) {
    if (source is String) {
      return StructuredText(text: source);
    }
    final json = (source as Map<Object?, Object?>?)?.cast<String, Object?>();
    final matches = ((json?['matches'] as List?) ?? <Object?>[])
        .map(
          (match) => (match as Map<Object?, Object?>).cast<String, Object?>(),
        )
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
/// Base type for autocomplete suggestions returned by Places API (New).
sealed class AutocompleteSuggestion {
  /// Creates a generic autocomplete suggestion.
  const AutocompleteSuggestion({
    required this.fullText,
    this.rawData = const <String, Object?>{},
  });

  /// Full display text returned by Google for this suggestion.
  final StructuredText fullText;

  /// Raw suggestion payload from Google.
  final Map<String, Object?> rawData;

  /// Plain text value of [fullText].
  String get displayText => fullText.text;

  /// Parses either a place or query prediction from a REST suggestion object.
  factory AutocompleteSuggestion.fromRestJson(Map<String, Object?> json) {
    if (json['queryPrediction'] != null) {
      return QuerySuggestion.fromRestJson(json);
    }
    return PlaceSuggestion.fromRestJson(json);
  }
}

@immutable
/// Lightweight place autocomplete suggestion returned by Places API (New).
class PlaceSuggestion extends AutocompleteSuggestion {
  const PlaceSuggestion({
    required this.placeId,
    required this.placeResourceName,
    required super.fullText,
    required this.primaryText,
    this.secondaryText,
    this.distanceMeters,
    this.types = const <String>[],
    super.rawData = const <String, Object?>{},
  });

  /// Stable Google place id for the suggested place.
  final String placeId;

  /// Full Google resource name, such as `places/ChIJ...`.
  final String placeResourceName;

  /// Primary display text, typically the place name.
  final StructuredText primaryText;

  /// Secondary display text, typically address or locality context.
  final StructuredText? secondaryText;

  /// Distance from the request origin, when Google includes it.
  final int? distanceMeters;

  /// Place types returned for this suggestion.
  final List<String> types;

  factory PlaceSuggestion.fromRestJson(Map<String, Object?> json) {
    final prediction =
        (json['placePrediction'] as Map<Object?, Object?>?)
            ?.cast<String, Object?>() ??
        json;
    final structuredFormat =
        (prediction['structuredFormat'] as Map<Object?, Object?>?)
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
/// Query autocomplete suggestion returned when query predictions are enabled.
class QuerySuggestion extends AutocompleteSuggestion {
  /// Creates a query suggestion.
  const QuerySuggestion({
    required super.fullText,
    this.matches = const <TextMatch>[],
    super.rawData = const <String, Object?>{},
  });

  /// Match ranges returned for the suggested query text.
  final List<TextMatch> matches;

  factory QuerySuggestion.fromRestJson(Map<String, Object?> json) {
    final prediction =
        (json['queryPrediction'] as Map<Object?, Object?>?)
            ?.cast<String, Object?>() ??
        json;
    final fullText = StructuredText.fromJson(prediction['text']);
    return QuerySuggestion(
      fullText: fullText,
      matches: fullText.matches,
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
/// Structured component of a place address, such as route or locality.
///
/// Google may return multiple types for a single component, and the order is
/// not guaranteed to be stable between requests.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#AddressComponent
class PlaceAddressComponent {
  /// Creates a structured address component.
  const PlaceAddressComponent({
    required this.longText,
    this.shortText,
    this.types = const <String>[],
    this.languageCode,
  });

  /// Full component text, such as `California`.
  final String longText;

  /// Short component text, such as `CA`, when available.
  final String? shortText;

  /// Google address component types for this component.
  final List<String> types;

  /// Optional BCP-47 language code for the component text.
  final String? languageCode;

  factory PlaceAddressComponent.fromJson(Map<String, Object?> json) =>
      PlaceAddressComponent(
        longText: (json['longText'] ?? '') as String,
        shortText: json['shortText'] as String?,
        types: ((json['types'] as List?) ?? <Object?>[])
            .whereType<String>()
            .toList(growable: false),
        languageCode: json['languageCode'] as String?,
      );

  /// Whether this component includes the supplied Google component type.
  bool hasType(String type) => types.contains(type);
}

@immutable
/// Postal-address representation returned by Google Places API (New).
///
/// This schema is useful when you need normalized city, administrative area,
/// postal code, or country information in addition to formatted address text.
///
/// Official reference:
/// https://developers.google.com/maps/documentation/places/web-service/reference/rest/v1/places#PostalAddress
class PlacePostalAddress {
  /// Creates a normalized postal-address value.
  const PlacePostalAddress({
    this.revision,
    required this.regionCode,
    this.languageCode,
    this.postalCode,
    this.sortingCode,
    this.administrativeArea,
    this.locality,
    this.sublocality,
    this.addressLines = const <String>[],
    this.recipients = const <String>[],
    this.organization,
  });

  /// Optional schema revision number.
  final int? revision;

  /// CLDR region code for the address.
  final String regionCode;

  /// Optional BCP-47 language code for the address.
  final String? languageCode;

  /// Postal code for the address.
  final String? postalCode;

  /// Optional sorting code used in some countries.
  final String? sortingCode;

  /// Administrative area such as state or province.
  final String? administrativeArea;

  /// Locality such as city or town.
  final String? locality;

  /// Sublocality such as district or neighborhood.
  final String? sublocality;

  /// Street-address lines.
  final List<String> addressLines;

  /// Named recipients associated with the address.
  final List<String> recipients;

  /// Organization associated with the address.
  final String? organization;

  factory PlacePostalAddress.fromJson(Map<String, Object?> json) =>
      PlacePostalAddress(
        revision: (json['revision'] as num?)?.toInt(),
        regionCode: (json['regionCode'] ?? '') as String,
        languageCode: json['languageCode'] as String?,
        postalCode: json['postalCode'] as String?,
        sortingCode: json['sortingCode'] as String?,
        administrativeArea: json['administrativeArea'] as String?,
        locality: json['locality'] as String?,
        sublocality: json['sublocality'] as String?,
        addressLines: ((json['addressLines'] as List?) ?? <Object?>[])
            .whereType<String>()
            .toList(growable: false),
        recipients: ((json['recipients'] as List?) ?? <Object?>[])
            .whereType<String>()
            .toList(growable: false),
        organization: json['organization'] as String?,
      );
}

@immutable
/// Photo metadata returned in rich place details.
class PlacePhoto {
  /// Creates a photo metadata object.
  const PlacePhoto({
    required this.name,
    this.widthPx,
    this.heightPx,
    this.googleMapsUri,
    this.authorAttributions = const <Map<String, Object?>>[],
  });

  /// Stable Google photo resource name.
  final String name;

  /// Photo width in pixels, when known.
  final int? widthPx;

  /// Photo height in pixels, when known.
  final int? heightPx;

  /// Google Maps URI for the photo, when provided.
  final String? googleMapsUri;

  /// Attribution blocks that should accompany the photo.
  final List<Map<String, Object?>> authorAttributions;

  factory PlacePhoto.fromJson(Map<String, Object?> json) => PlacePhoto(
    name: (json['name'] ?? '') as String,
    widthPx: (json['widthPx'] as num?)?.toInt(),
    heightPx: (json['heightPx'] as num?)?.toInt(),
    googleMapsUri: json['googleMapsUri'] as String?,
    authorAttributions: ((json['authorAttributions'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false),
  );
}

@immutable
/// Request payload for Place Photos (New) media lookup.
class PhotoMediaRequest {
  /// Creates a photo media request.
  const PhotoMediaRequest({
    required this.name,
    this.maxWidthPx,
    this.maxHeightPx,
  });

  /// Photo resource name, such as `places/{placeId}/photos/{photoId}`.
  final String name;

  /// Maximum requested image width in pixels.
  final int? maxWidthPx;

  /// Maximum requested image height in pixels.
  final int? maxHeightPx;

  /// Validates request invariants before serialization.
  void validate() {
    if (name.trim().isEmpty) {
      throw const PlacesException('Photo media name cannot be empty.');
    }
    if (maxWidthPx == null && maxHeightPx == null) {
      throw const PlacesException(
        'Photo media requests require maxWidthPx, maxHeightPx, or both.',
      );
    }
    if ((maxWidthPx ?? 1) <= 0 || (maxHeightPx ?? 1) <= 0) {
      throw const PlacesException('Photo media dimensions must be positive.');
    }
  }

  /// Resource path used by Places Photo Media requests.
  String get mediaPath {
    final trimmed = name.startsWith('/') ? name.substring(1) : name;
    return trimmed.endsWith('/media') ? trimmed : '$trimmed/media';
  }

  /// Query parameters for the Places Photo Media endpoint.
  Map<String, String> toQueryParameters({bool skipHttpRedirect = true}) {
    validate();
    return <String, String>{
      if (maxWidthPx != null) 'maxWidthPx': maxWidthPx!.toString(),
      if (maxHeightPx != null) 'maxHeightPx': maxHeightPx!.toString(),
      if (skipHttpRedirect) 'skipHttpRedirect': 'true',
    };
  }
}

@immutable
/// Response payload for Place Photos (New) media lookup.
class PlacePhotoMedia {
  /// Creates a photo media response.
  const PlacePhotoMedia({
    required this.name,
    required this.photoUri,
    this.rawData = const <String, Object?>{},
  });

  /// Photo media resource name.
  final String name;

  /// Resolved URI for the photo media.
  final String photoUri;

  /// Full raw payload from Google.
  final Map<String, Object?> rawData;

  factory PlacePhotoMedia.fromJson(Map<String, Object?> json) =>
      PlacePhotoMedia(
        name: (json['name'] ?? '') as String,
        photoUri: (json['photoUri'] ?? '') as String,
        rawData: Map<String, Object?>.unmodifiable(json),
      );
}

@immutable
/// Review metadata returned in rich place details.
class PlaceReview {
  /// Creates a place review value.
  const PlaceReview({
    required this.authorName,
    required this.text,
    this.rating,
    this.relativePublishTimeDescription,
    this.googleMapsUri,
    this.originalText,
  });

  /// Review author display name.
  final String authorName;

  /// Localized review text.
  final LocalizedText text;

  /// Rating value supplied with the review.
  final double? rating;

  /// Relative publish time such as `2 weeks ago`.
  final String? relativePublishTimeDescription;

  /// Google Maps URI for the review or place context.
  final String? googleMapsUri;

  /// Original untranslated review text, when provided.
  final LocalizedText? originalText;

  factory PlaceReview.fromJson(Map<String, Object?> json) {
    final authorAttribution =
        (json['authorAttribution'] as Map<Object?, Object?>?)
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
  /// Creates a rich place-details object.
  const PlaceData({
    required this.id,
    this.resourceName,
    this.displayName,
    this.formattedAddress,
    this.shortFormattedAddress,
    this.postalAddress,
    this.addressComponents = const <PlaceAddressComponent>[],
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
    this.addressDescriptor,
    this.evChargeOptions,
    this.fuelOptions,
    this.generativeSummary,
    this.pureServiceAreaBusiness,
    this.movedPlace,
    this.movedPlaceId,
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

  /// Structured postal-address representation, when requested.
  final PlacePostalAddress? postalAddress;

  /// Structured address components, when requested.
  final List<PlaceAddressComponent> addressComponents;

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

  /// Google Maps URI for this place.
  final String? googleMapsUri;

  /// Website URI for this place, when available.
  final String? websiteUri;

  /// National-format phone number.
  final String? nationalPhoneNumber;

  /// International-format phone number.
  final String? internationalPhoneNumber;

  /// Average user rating.
  final double? rating;

  /// Count of user ratings used in [rating].
  final int? userRatingCount;

  /// Price level returned by Google.
  final String? priceLevel;

  /// Business status returned by Google.
  final String? businessStatus;

  /// Base URI for the place icon mask.
  final String? iconMaskBaseUri;

  /// Background color associated with the place icon.
  final String? iconBackgroundColor;

  /// UTC offset in minutes for the place, when provided by Google.
  final int? utcOffsetMinutes;

  /// Whether delivery is available.
  final bool? delivery;

  /// Whether dine-in is available.
  final bool? dineIn;

  /// Whether takeout is available.
  final bool? takeout;

  /// Whether reservations are supported.
  final bool? reservable;

  /// Whether breakfast is served.
  final bool? servesBreakfast;

  /// Whether lunch is served.
  final bool? servesLunch;

  /// Whether dinner is served.
  final bool? servesDinner;

  /// Whether beer is served.
  final bool? servesBeer;

  /// Whether wine is served.
  final bool? servesWine;

  /// Whether dessert is served.
  final bool? servesDessert;

  /// Whether coffee is served.
  final bool? servesCoffee;

  /// Whether outdoor seating is available.
  final bool? outdoorSeating;

  /// Whether restrooms are available.
  final bool? restroom;

  /// Whether the place is good for children.
  final bool? goodForChildren;

  /// Whether the place is good for groups.
  final bool? goodForGroups;

  /// Current opening-hours payload returned by Google.
  final Map<String, Object?>? currentOpeningHours;

  /// Regular opening-hours payload returned by Google.
  final Map<String, Object?>? regularOpeningHours;

  /// Address descriptor payload returned by Google, when available.
  final Map<String, Object?>? addressDescriptor;

  /// EV charging options payload returned by Google, when available.
  final Map<String, Object?>? evChargeOptions;

  /// Fuel options payload returned by Google, when available.
  final Map<String, Object?>? fuelOptions;

  /// AI-generated place summary payload returned by Google, when requested.
  final Map<String, Object?>? generativeSummary;

  /// Whether this place is a pure service-area business.
  final bool? pureServiceAreaBusiness;

  /// Resource name of the moved-to place when this place has moved.
  final String? movedPlace;

  /// Place id of the moved-to place when this place has moved.
  final String? movedPlaceId;

  /// Reviews returned when review fields are requested.
  final List<PlaceReview> reviews;

  /// Photos returned when photo fields are requested.
  final List<PlacePhoto> photos;

  /// Full raw payload from Google.
  final Map<String, Object?> rawData;

  /// Street route component, such as `Broadway`.
  String? get route => _addressComponent('route')?.longText;

  /// Short street route component, when Google provides it.
  String? get routeShort => _addressComponent('route')?.shortText;

  /// Street number component, such as `151`.
  String? get streetNumber => _addressComponent('street_number')?.longText;

  /// Short street number component, when Google provides it.
  String? get streetNumberShort =>
      _addressComponent('street_number')?.shortText;

  /// Locality component, typically a city or town.
  String? get locality =>
      _addressComponent('locality')?.longText ?? postalAddress?.locality;

  /// Short locality component, when Google provides it.
  String? get localityShort => _addressComponent('locality')?.shortText;

  /// Administrative area component, typically state/province/region.
  String? get administrativeArea =>
      _addressComponent('administrative_area_level_1')?.longText ??
      postalAddress?.administrativeArea;

  /// Short administrative area component, when Google provides it.
  String? get administrativeAreaShort =>
      _addressComponent('administrative_area_level_1')?.shortText;

  /// Postal code component.
  String? get postalCode =>
      _addressComponent('postal_code')?.longText ?? postalAddress?.postalCode;

  /// Short postal code component, when Google provides it.
  String? get postalCodeShort => _addressComponent('postal_code')?.shortText;

  /// Country name component.
  String? get country => _addressComponent('country')?.longText;

  /// Short country component, typically an ISO/CLDR-like country code.
  String? get countryShort => _addressComponent('country')?.shortText;

  /// Country/region code from the postal address schema.
  String? get countryCode => postalAddress?.regionCode;

  /// Short country/region code from address components when available, falling
  /// back to [countryCode].
  String? get countryCodeShort =>
      _addressComponent('country')?.shortText ?? countryCode;

  factory PlaceData.fromJson(Map<String, Object?> json) => PlaceData(
    id: (json['id'] ?? '') as String,
    resourceName: json['name'] as String?,
    displayName: json['displayName'] == null
        ? null
        : LocalizedText.fromJson(json['displayName']),
    formattedAddress: json['formattedAddress'] as String?,
    shortFormattedAddress: json['shortFormattedAddress'] as String?,
    postalAddress: (json['postalAddress'] as Map<Object?, Object?>?) == null
        ? null
        : PlacePostalAddress.fromJson(
            (json['postalAddress'] as Map<Object?, Object?>)
                .cast<String, Object?>(),
          ),
    addressComponents: ((json['addressComponents'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map(
          (component) =>
              PlaceAddressComponent.fromJson(component.cast<String, Object?>()),
        )
        .toList(growable: false),
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
    currentOpeningHours: (json['currentOpeningHours'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    regularOpeningHours: (json['regularOpeningHours'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    addressDescriptor: (json['addressDescriptor'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    evChargeOptions: (json['evChargeOptions'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    fuelOptions: (json['fuelOptions'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    generativeSummary: (json['generativeSummary'] as Map<Object?, Object?>?)
        ?.cast<String, Object?>(),
    pureServiceAreaBusiness: json['pureServiceAreaBusiness'] as bool?,
    movedPlace: json['movedPlace'] as String?,
    movedPlaceId: json['movedPlaceId'] as String?,
    reviews: ((json['reviews'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((review) => PlaceReview.fromJson(review.cast<String, Object?>()))
        .toList(growable: false),
    photos: ((json['photos'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((photo) => PlacePhoto.fromJson(photo.cast<String, Object?>()))
        .toList(growable: false),
    rawData: Map<String, Object?>.unmodifiable(json),
  );

  PlaceAddressComponent? _addressComponent(String type) {
    for (final component in addressComponents) {
      if (component.hasType(type)) {
        return component;
      }
    }
    return null;
  }
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
  /// Creates a Places autocomplete request.
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
    this.includeQueryPredictions = false,
  });

  /// User-entered search text.
  final String input;

  /// Optional session token reused across autocomplete and details calls.
  final AutocompleteSessionToken? sessionToken;

  /// Preferred BCP-47 language code for returned suggestions.
  final String? languageCode;

  /// Preferred CLDR region code for returned suggestions.
  final String? regionCode;

  /// Cursor position inside [input], when available.
  final int? inputOffset;

  /// Origin used for distance calculations.
  final PlaceCoordinates? origin;

  /// Soft geographic preference for suggestions.
  final LocationBias? locationBias;

  /// Hard geographic restriction for suggestions.
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

  /// Whether query predictions should be included alongside place predictions.
  ///
  /// [PlacesClient.autocomplete] keeps returning only [PlaceSuggestion] values.
  /// Use [PlacesClient.autocompleteSuggestions] to receive both place and
  /// query suggestions.
  final bool includeQueryPredictions;

  /// Validates request invariants before serialization.
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

  /// Serializes the request for the Places HTTP autocomplete endpoint.
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
      if (includeQueryPredictions) 'includeQueryPredictions': true,
    };
  }
}

@immutable
/// Request payload for Place Details (New).
class PlaceDetailsRequest {
  /// Creates a Place Details request.
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
  /// Creates a text-search request.
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

  /// Soft geographic preference applied to the search.
  final LocationBias? locationBias;

  /// Hard geographic restriction applied to the search.
  final LocationRestriction? locationRestriction;

  /// Maximum number of results requested from Google.
  final int? maxResultCount;

  /// Minimum acceptable average rating.
  final double? minRating;

  /// Whether only currently open places should be returned.
  final bool? openNow;

  /// Ranking behavior for text-search results.
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
  /// Creates a nearby-search request.
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

  /// Serializes the request for the Places nearby-search endpoint.
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
  final json = (source as Map<Object?, Object?>).cast<String, Object?>();
  return PlaceCoordinates(
    latitude: _toDouble(json['latitude'] ?? json['lat']) ?? 0,
    longitude: _toDouble(json['longitude'] ?? json['lng']) ?? 0,
  );
}

PlaceViewport? _parseViewport(Object? source) {
  if (source == null) {
    return null;
  }
  final json = (source as Map<Object?, Object?>).cast<String, Object?>();
  final northeast = _parseCoordinates(json['northeast'] ?? json['high']);
  final southwest = _parseCoordinates(json['southwest'] ?? json['low']);
  if (northeast == null || southwest == null) {
    return null;
  }
  return PlaceViewport(northeast: northeast, southwest: southwest);
}

String prettyJson(Map<String, Object?> value) =>
    const JsonEncoder.withIndent('  ').convert(value);
