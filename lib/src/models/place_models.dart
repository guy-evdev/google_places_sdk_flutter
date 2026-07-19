import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Stable categories exposed by [PlacesException].
enum PlacesErrorKind {
  /// A request failed package-side validation before any operation was sent.
  validation,

  /// Client or transport configuration is invalid.
  configuration,

  /// The underlying network transport failed before receiving a response.
  network,

  /// The configured operation deadline elapsed.
  timeout,

  /// Work was explicitly cancelled by the caller or package lifecycle.
  cancellation,

  /// A non-success HTTP response did not contain a Google API error payload.
  http,

  /// Google returned a structured API error.
  googleApi,

  /// A configured proxy returned an invalid or proxy-specific response.
  proxy,

  /// Maps JavaScript loading or invocation failed.
  javascript,

  /// The failure could not be classified more specifically.
  unknown,
}

/// Public operations that can be attached to a [PlacesException].
enum PlacesOperation {
  autocomplete,
  placeDetails,
  photoMedia,
  timeZone,
  textSearch,
  nearbySearch,
  clientInitialization,
}

@immutable
/// Exception thrown for invalid requests or Places API failures.
class PlacesException implements Exception {
  /// Creates an exception representing a request validation or API failure.
  const PlacesException(
    this.message, {
    this.kind = PlacesErrorKind.unknown,
    this.statusCode,
    this.code,
    this.retryable = false,
    this.operation,
    this.details,
    this.metadata = const <String, Object?>{},
  });

  /// Creates a package-side validation error.
  const PlacesException.validation(
    this.message, {
    this.operation,
    this.code = 'invalid_request',
    this.metadata = const <String, Object?>{},
  }) : kind = PlacesErrorKind.validation,
       statusCode = null,
       retryable = false,
       details = null;

  /// Creates a client configuration error.
  const PlacesException.configuration(
    this.message, {
    this.operation = PlacesOperation.clientInitialization,
    this.code = 'invalid_configuration',
    this.metadata = const <String, Object?>{},
  }) : kind = PlacesErrorKind.configuration,
       statusCode = null,
       retryable = false,
       details = null;

  /// Human-readable description of the failure.
  final String message;

  /// Stable failure category suitable for programmatic handling.
  final PlacesErrorKind kind;

  /// Optional HTTP status code when the error came from a network request.
  final int? statusCode;

  /// Optional stable package or Google error code.
  final String? code;

  /// Whether retrying later may reasonably succeed.
  final bool retryable;

  /// Package operation that failed, when known.
  final PlacesOperation? operation;

  /// Optional structured details returned by Google.
  ///
  /// This field is retained for source compatibility. Package-generated
  /// exceptions keep it free of request credentials and session tokens.
  final Object? details;

  /// Redacted structured context safe to include in diagnostics.
  final Map<String, Object?> metadata;

  @override
  String toString() {
    final operationLabel = operation == null ? '' : ', ${operation!.name}';
    final statusLabel = statusCode == null ? '' : ', HTTP $statusCode';
    final codeLabel = code == null ? '' : ', $code';
    return 'PlacesException(${kind.name}$operationLabel$statusLabel'
        '$codeLabel): $message';
  }
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

  /// Validates Google's URL- and filename-safe token requirement.
  void validate({PlacesOperation? operation}) {
    if (value.isEmpty || !RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value)) {
      throw PlacesException.validation(
        'Autocomplete session tokens must be non-empty URL-safe strings.',
        operation: operation,
        code: 'invalid_session_token',
      );
    }
  }

  @override
  String toString() => 'AutocompleteSessionToken(<redacted>)';
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

  /// Validates the documented latitude and longitude ranges.
  void validate({PlacesOperation? operation}) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw PlacesException.validation(
        'Latitude must be finite and between -90 and 90.',
        operation: operation,
        code: 'invalid_latitude',
      );
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw PlacesException.validation(
        'Longitude must be finite and between -180 and 180.',
        operation: operation,
        code: 'invalid_longitude',
      );
    }
  }

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
  googleMapsTypeLabel('googleMapsTypeLabel'),
  businessStatus('businessStatus'),
  openingDate('openingDate'),
  googleMapsUri('googleMapsUri'),
  googleMapsLinks('googleMapsLinks'),
  websiteUri('websiteUri'),
  nationalPhoneNumber('nationalPhoneNumber'),
  internationalPhoneNumber('internationalPhoneNumber'),
  rating('rating'),
  userRatingCount('userRatingCount'),
  priceLevel('priceLevel'),
  priceRange('priceRange'),
  plusCode('plusCode'),
  attributions('attributions'),
  iconMaskBaseUri('iconMaskBaseUri'),
  iconBackgroundColor('iconBackgroundColor'),
  utcOffsetMinutes('utcOffsetMinutes'),
  timeZone('timeZone'),
  editorialSummary('editorialSummary'),
  currentOpeningHours('currentOpeningHours'),
  regularOpeningHours('regularOpeningHours'),
  currentSecondaryOpeningHours('currentSecondaryOpeningHours'),
  regularSecondaryOpeningHours('regularSecondaryOpeningHours'),
  photos('photos'),
  reviews('reviews'),
  addressComponents('addressComponents'),
  containingPlaces('containingPlaces'),
  subDestinations('subDestinations'),
  delivery('delivery'),
  dineIn('dineIn'),
  takeout('takeout'),
  curbsidePickup('curbsidePickup'),
  reservable('reservable'),
  servesBreakfast('servesBreakfast'),
  servesLunch('servesLunch'),
  servesDinner('servesDinner'),
  servesBeer('servesBeer'),
  servesWine('servesWine'),
  servesBrunch('servesBrunch'),
  servesVegetarianFood('servesVegetarianFood'),
  servesCocktails('servesCocktails'),
  servesDessert('servesDessert'),
  servesCoffee('servesCoffee'),
  outdoorSeating('outdoorSeating'),
  liveMusic('liveMusic'),
  menuForChildren('menuForChildren'),
  allowsDogs('allowsDogs'),
  restroom('restroom'),
  goodForChildren('goodForChildren'),
  goodForGroups('goodForGroups'),
  goodForWatchingSports('goodForWatchingSports'),
  paymentOptions('paymentOptions'),
  parkingOptions('parkingOptions'),
  accessibilityOptions('accessibilityOptions'),
  addressDescriptor('addressDescriptor'),
  evChargeOptions('evChargeOptions'),
  fuelOptions('fuelOptions'),
  generativeSummary('generativeSummary'),
  reviewSummary('reviewSummary'),
  evChargeAmenitySummary('evChargeAmenitySummary'),
  neighborhoodSummary('neighborhoodSummary'),
  consumerAlert('consumerAlert'),
  transitStation('transitStation'),
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

/// Price levels accepted by Places Text Search (New).
///
/// [free] is returned by Google for free places, but is not accepted as a Text
/// Search filter. [unspecified] is included for forward-compatible response
/// mapping and is likewise not a valid request filter.
enum PlacePriceLevel {
  unspecified('PRICE_LEVEL_UNSPECIFIED'),
  free('PRICE_LEVEL_FREE'),
  inexpensive('PRICE_LEVEL_INEXPENSIVE'),
  moderate('PRICE_LEVEL_MODERATE'),
  expensive('PRICE_LEVEL_EXPENSIVE'),
  veryExpensive('PRICE_LEVEL_VERY_EXPENSIVE');

  const PlacePriceLevel(this.restName);

  /// Raw enum value expected by the Places HTTP API.
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
  const PlaceSelection({
    required this.suggestion,
    this.sessionToken,
    this.place,
    this.timeZone,
  });

  /// The lightweight autocomplete suggestion the user selected.
  final PlaceSuggestion suggestion;

  /// Autocomplete session token active when [suggestion] was selected.
  ///
  /// This remains available after the controller starts its next session so
  /// headless and deferred-details flows can preserve session identity.
  final AutocompleteSessionToken? sessionToken;

  /// Rich place details resolved for the selection, if requested.
  final PlaceData? place;

  /// Time-zone data resolved for the selection, if requested.
  final PlaceTimeZoneData? timeZone;

  /// Convenience getter for the selected [PlaceSuggestion.placeId].
  String get placeId => suggestion.placeId;

  /// Convenience getter for the selected [AutocompleteSuggestion.displayText].
  String get displayText => suggestion.displayText;

  /// Whether [place] is available.
  bool get hasResolvedPlace => place != null;

  /// Whether [timeZone] is available.
  bool get hasTimeZone => timeZone != null;

  PlaceSelection copyWith({
    PlaceSuggestion? suggestion,
    AutocompleteSessionToken? sessionToken,
    PlaceData? place,
    PlaceTimeZoneData? timeZone,
  }) {
    return PlaceSelection(
      suggestion: suggestion ?? this.suggestion,
      sessionToken: sessionToken ?? this.sessionToken,
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
/// Author attribution that must be shown with a displayed place photo.
class PlacePhotoAuthorAttribution {
  /// Creates a photo author attribution.
  const PlacePhotoAuthorAttribution({
    required this.displayName,
    this.uri,
    this.photoUri,
  });

  /// Author name to display with the photo.
  final String displayName;

  /// Link to the author's Google Maps profile, when provided.
  final String? uri;

  /// Author profile-photo URI, when provided.
  final String? photoUri;

  /// Parses Google's author-attribution payload.
  factory PlacePhotoAuthorAttribution.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlacePhotoAuthorAttribution(
      displayName: (json?['displayName'] ?? '') as String,
      uri: json?['uri'] as String?,
      photoUri: (json?['photoUri'] ?? json?['photoURI']) as String?,
    );
  }
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

  /// Typed author attributions that must be rendered with a displayed photo.
  ///
  /// Google requires every non-empty attribution returned with a photo to be
  /// shown wherever that photo is displayed.
  List<PlacePhotoAuthorAttribution> get authors => List.unmodifiable(
    authorAttributions.map(PlacePhotoAuthorAttribution.fromJson),
  );

  factory PlacePhoto.fromJson(Map<String, Object?> json) => PlacePhoto(
    name: (json['name'] ?? '') as String,
    widthPx: (json['widthPx'] as num?)?.toInt(),
    heightPx: (json['heightPx'] as num?)?.toInt(),
    googleMapsUri: (json['googleMapsUri'] ?? json['googleMapsURI']) as String?,
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
      throw const PlacesException.validation(
        'Photo media name cannot be empty.',
        operation: PlacesOperation.photoMedia,
        code: 'empty_photo_name',
      );
    }
    final normalizedName = name.startsWith('/') ? name.substring(1) : name;
    if (!RegExp(
      r'^places/[^/]+/photos/[^/]+(?:/media)?$',
    ).hasMatch(normalizedName)) {
      throw const PlacesException.validation(
        'Photo media name must match places/{placeId}/photos/{photoId}.',
        operation: PlacesOperation.photoMedia,
        code: 'invalid_photo_name',
      );
    }
    if (maxWidthPx == null && maxHeightPx == null) {
      throw const PlacesException.validation(
        'Photo media requests require maxWidthPx, maxHeightPx, or both.',
        operation: PlacesOperation.photoMedia,
        code: 'missing_photo_dimensions',
      );
    }
    if (!_validPhotoDimension(maxWidthPx) ||
        !_validPhotoDimension(maxHeightPx)) {
      throw const PlacesException.validation(
        'Photo media dimensions must be between 1 and 4800 pixels.',
        operation: PlacesOperation.photoMedia,
        code: 'invalid_photo_dimensions',
      );
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
      googleMapsUri:
          (json['googleMapsUri'] ?? json['googleMapsURI']) as String?,
      originalText: json['originalText'] == null
          ? null
          : LocalizedText.fromJson(json['originalText']),
    );
  }
}

@immutable
/// Whole or partial Gregorian calendar date returned by Places API.
class PlaceDate {
  const PlaceDate({required this.year, required this.month, required this.day});

  final int year;
  final int month;
  final int day;

  /// Whether this value contains a complete year, month, and day.
  bool get isComplete => year > 0 && month > 0 && day > 0;

  factory PlaceDate.fromJson(Object? source) {
    if (source is String) {
      final parsed = DateTime.tryParse(source);
      if (parsed != null) {
        return PlaceDate(
          year: parsed.year,
          month: parsed.month,
          day: parsed.day,
        );
      }
    }
    final json = _jsonMap(source);
    return PlaceDate(
      year: (json?['year'] as num?)?.toInt() ?? 0,
      month: (json?['month'] as num?)?.toInt() ?? 0,
      day: (json?['day'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
/// Open Location Code values for a place.
class PlacePlusCode {
  const PlacePlusCode({this.globalCode, this.compoundCode});

  final String? globalCode;
  final String? compoundCode;

  factory PlacePlusCode.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlacePlusCode(
      globalCode: json?['globalCode'] as String?,
      compoundCode: json?['compoundCode'] as String?,
    );
  }
}

@immutable
/// IANA time-zone identity embedded in a Place response.
class PlaceTimeZone {
  const PlaceTimeZone({required this.id, this.version});

  final String id;
  final String? version;

  factory PlaceTimeZone.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTimeZone(
      id: (json?['id'] ?? '') as String,
      version: json?['version'] as String?,
    );
  }
}

@immutable
/// Data-provider attribution that must be displayed with a place.
class PlaceAttribution {
  const PlaceAttribution({required this.provider, this.providerUri});

  final String provider;
  final String? providerUri;

  factory PlaceAttribution.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceAttribution(
      provider: (json?['provider'] ?? '') as String,
      providerUri: (json?['providerUri'] ?? json?['providerURI']) as String?,
    );
  }
}

@immutable
/// Payment methods accepted by a place.
class PlacePaymentOptions {
  const PlacePaymentOptions({
    this.acceptsCreditCards,
    this.acceptsDebitCards,
    this.acceptsCashOnly,
    this.acceptsNfc,
  });

  final bool? acceptsCreditCards;
  final bool? acceptsDebitCards;
  final bool? acceptsCashOnly;
  final bool? acceptsNfc;

  factory PlacePaymentOptions.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlacePaymentOptions(
      acceptsCreditCards: json?['acceptsCreditCards'] as bool?,
      acceptsDebitCards: json?['acceptsDebitCards'] as bool?,
      acceptsCashOnly: json?['acceptsCashOnly'] as bool?,
      acceptsNfc: (json?['acceptsNfc'] ?? json?['acceptsNFC']) as bool?,
    );
  }
}

@immutable
/// Parking options offered by a place.
class PlaceParkingOptions {
  const PlaceParkingOptions({
    this.freeParkingLot,
    this.paidParkingLot,
    this.freeStreetParking,
    this.paidStreetParking,
    this.valetParking,
    this.freeGarageParking,
    this.paidGarageParking,
  });

  final bool? freeParkingLot;
  final bool? paidParkingLot;
  final bool? freeStreetParking;
  final bool? paidStreetParking;
  final bool? valetParking;
  final bool? freeGarageParking;
  final bool? paidGarageParking;

  factory PlaceParkingOptions.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceParkingOptions(
      freeParkingLot:
          (json?['freeParkingLot'] ?? json?['hasFreeParkingLot']) as bool?,
      paidParkingLot:
          (json?['paidParkingLot'] ?? json?['hasPaidParkingLot']) as bool?,
      freeStreetParking:
          (json?['freeStreetParking'] ?? json?['hasFreeStreetParking'])
              as bool?,
      paidStreetParking:
          (json?['paidStreetParking'] ?? json?['hasPaidStreetParking'])
              as bool?,
      valetParking:
          (json?['valetParking'] ?? json?['hasValetParking']) as bool?,
      freeGarageParking:
          (json?['freeGarageParking'] ?? json?['hasFreeGarageParking'])
              as bool?,
      paidGarageParking:
          (json?['paidGarageParking'] ?? json?['hasPaidGarageParking'])
              as bool?,
    );
  }
}

@immutable
/// Wheelchair accessibility options offered by a place.
class PlaceAccessibilityOptions {
  const PlaceAccessibilityOptions({
    this.wheelchairAccessibleParking,
    this.wheelchairAccessibleEntrance,
    this.wheelchairAccessibleRestroom,
    this.wheelchairAccessibleSeating,
  });

  final bool? wheelchairAccessibleParking;
  final bool? wheelchairAccessibleEntrance;
  final bool? wheelchairAccessibleRestroom;
  final bool? wheelchairAccessibleSeating;

  factory PlaceAccessibilityOptions.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceAccessibilityOptions(
      wheelchairAccessibleParking:
          (json?['wheelchairAccessibleParking'] ??
                  json?['hasWheelchairAccessibleParking'])
              as bool?,
      wheelchairAccessibleEntrance:
          (json?['wheelchairAccessibleEntrance'] ??
                  json?['hasWheelchairAccessibleEntrance'])
              as bool?,
      wheelchairAccessibleRestroom:
          (json?['wheelchairAccessibleRestroom'] ??
                  json?['hasWheelchairAccessibleRestroom'])
              as bool?,
      wheelchairAccessibleSeating:
          (json?['wheelchairAccessibleSeating'] ??
                  json?['hasWheelchairAccessibleSeating'])
              as bool?,
    );
  }
}

@immutable
/// Place id and resource-name reference used for containing/sub-destinations.
class PlaceResourceReference {
  const PlaceResourceReference({required this.id, required this.resourceName});

  final String id;
  final String resourceName;

  factory PlaceResourceReference.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceResourceReference(
      id: (json?['id'] ?? '') as String,
      resourceName: (json?['name'] ?? json?['resourceName'] ?? '') as String,
    );
  }
}

@immutable
/// Google Maps action links associated with a place.
class PlaceGoogleMapsLinks {
  const PlaceGoogleMapsLinks({
    this.directionsUri,
    this.placeUri,
    this.writeAReviewUri,
    this.reviewsUri,
    this.photosUri,
  });

  final String? directionsUri;
  final String? placeUri;
  final String? writeAReviewUri;
  final String? reviewsUri;
  final String? photosUri;

  factory PlaceGoogleMapsLinks.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceGoogleMapsLinks(
      directionsUri:
          (json?['directionsUri'] ?? json?['directionsURI']) as String?,
      placeUri: (json?['placeUri'] ?? json?['placeURI']) as String?,
      writeAReviewUri:
          (json?['writeAReviewUri'] ?? json?['writeAReviewURI']) as String?,
      reviewsUri: (json?['reviewsUri'] ?? json?['reviewsURI']) as String?,
      photosUri: (json?['photosUri'] ?? json?['photosURI']) as String?,
    );
  }
}

@immutable
/// Currency amount returned inside a place price range.
class PlaceMoney {
  const PlaceMoney({
    required this.currencyCode,
    required this.units,
    required this.nanos,
  });

  final String currencyCode;

  /// Whole units preserved as an int64-compatible decimal string.
  final String units;

  final int nanos;

  factory PlaceMoney.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceMoney(
      currencyCode: (json?['currencyCode'] ?? '') as String,
      units: (json?['units'] ?? '0').toString(),
      nanos: (json?['nanos'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
/// Inclusive start and optional exclusive end price for a place.
class PlacePriceRange {
  const PlacePriceRange({this.startPrice, this.endPrice});

  final PlaceMoney? startPrice;
  final PlaceMoney? endPrice;

  factory PlacePriceRange.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlacePriceRange(
      startPrice: json?['startPrice'] == null
          ? null
          : PlaceMoney.fromJson(json?['startPrice']),
      endPrice: json?['endPrice'] == null
          ? null
          : PlaceMoney.fromJson(json?['endPrice']),
    );
  }
}

@immutable
/// Icon metadata for a transit agency, line, or vehicle.
class PlaceTransitIcon {
  const PlaceTransitIcon({this.url, this.nameIncluded});

  final String? url;
  final bool? nameIncluded;

  factory PlaceTransitIcon.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTransitIcon(
      url: json?['url'] as String?,
      nameIncluded: json?['nameIncluded'] as bool?,
    );
  }
}

@immutable
/// Transit line serving a station.
class PlaceTransitLine {
  const PlaceTransitLine({
    required this.id,
    this.vehicleType,
    this.displayName,
    this.shortDisplayName,
    this.textColor,
    this.backgroundColor,
    this.url,
    this.icon,
    this.vehicleIcon,
  });

  final String id;
  final String? vehicleType;
  final LocalizedText? displayName;
  final LocalizedText? shortDisplayName;
  final String? textColor;
  final String? backgroundColor;
  final String? url;
  final PlaceTransitIcon? icon;
  final PlaceTransitIcon? vehicleIcon;

  factory PlaceTransitLine.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTransitLine(
      id: (json?['id'] ?? '') as String,
      vehicleType: json?['vehicleType'] as String?,
      displayName: json?['displayName'] == null
          ? null
          : LocalizedText.fromJson(json?['displayName']),
      shortDisplayName: json?['shortDisplayName'] == null
          ? null
          : LocalizedText.fromJson(json?['shortDisplayName']),
      textColor: json?['textColor'] as String?,
      backgroundColor: json?['backgroundColor'] as String?,
      url: json?['url'] as String?,
      icon: json?['icon'] == null
          ? null
          : PlaceTransitIcon.fromJson(json?['icon']),
      vehicleIcon: json?['vehicleIcon'] == null
          ? null
          : PlaceTransitIcon.fromJson(json?['vehicleIcon']),
    );
  }
}

@immutable
/// Transit agency serving a station.
class PlaceTransitAgency {
  PlaceTransitAgency({
    this.displayName,
    this.url,
    this.fareUrl,
    this.icon,
    List<PlaceTransitLine> lines = const <PlaceTransitLine>[],
  }) : lines = List<PlaceTransitLine>.unmodifiable(lines);

  final LocalizedText? displayName;
  final String? url;
  final String? fareUrl;
  final PlaceTransitIcon? icon;
  final List<PlaceTransitLine> lines;

  factory PlaceTransitAgency.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTransitAgency(
      displayName: json?['displayName'] == null
          ? null
          : LocalizedText.fromJson(json?['displayName']),
      url: json?['url'] as String?,
      fareUrl: (json?['fareUrl'] ?? json?['fareURL'])?.toString(),
      icon: json?['icon'] == null
          ? null
          : PlaceTransitIcon.fromJson(json?['icon']),
      lines: _jsonList(
        json?['lines'],
      ).map(PlaceTransitLine.fromJson).toList(growable: false),
    );
  }
}

@immutable
/// Boarding/alighting location within a transit station.
class PlaceTransitStop {
  const PlaceTransitStop({
    required this.id,
    this.displayName,
    this.platformCode,
    this.signageText,
    this.stopCode,
    this.location,
    this.wheelchairAccessibleEntrance,
  });

  final String id;
  final LocalizedText? displayName;
  final LocalizedText? platformCode;
  final LocalizedText? signageText;
  final LocalizedText? stopCode;
  final PlaceCoordinates? location;
  final bool? wheelchairAccessibleEntrance;

  factory PlaceTransitStop.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTransitStop(
      id: (json?['id'] ?? '') as String,
      displayName: json?['displayName'] == null
          ? null
          : LocalizedText.fromJson(json?['displayName']),
      platformCode: json?['platformCode'] == null
          ? null
          : LocalizedText.fromJson(json?['platformCode']),
      signageText: json?['signageText'] == null
          ? null
          : LocalizedText.fromJson(json?['signageText']),
      stopCode: json?['stopCode'] == null
          ? null
          : LocalizedText.fromJson(json?['stopCode']),
      location: _parseCoordinates(json?['location']),
      wheelchairAccessibleEntrance:
          (json?['wheelchairAccessibleEntrance'] ??
                  json?['hasWheelchairAccessibleEntrance'])
              as bool?,
    );
  }
}

@immutable
/// Transit-specific information for a place.
class PlaceTransitStation {
  PlaceTransitStation({
    this.displayName,
    List<PlaceTransitAgency> agencies = const <PlaceTransitAgency>[],
    List<PlaceTransitStop> stops = const <PlaceTransitStop>[],
  }) : agencies = List<PlaceTransitAgency>.unmodifiable(agencies),
       stops = List<PlaceTransitStop>.unmodifiable(stops);

  final LocalizedText? displayName;
  final List<PlaceTransitAgency> agencies;
  final List<PlaceTransitStop> stops;

  factory PlaceTransitStation.fromJson(Object? source) {
    final json = _jsonMap(source);
    return PlaceTransitStation(
      displayName: json?['displayName'] == null
          ? null
          : LocalizedText.fromJson(json?['displayName']),
      agencies: _jsonList(
        json?['agencies'],
      ).map(PlaceTransitAgency.fromJson).toList(growable: false),
      stops: _jsonList(
        json?['stops'],
      ).map(PlaceTransitStop.fromJson).toList(growable: false),
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
    this.adrFormatAddress,
    this.postalAddress,
    this.addressComponents = const <PlaceAddressComponent>[],
    this.plusCode,
    this.location,
    this.viewport,
    this.types = const <String>[],
    this.primaryType,
    this.primaryTypeDisplayName,
    this.googleMapsTypeLabel,
    this.googleMapsUri,
    this.googleMapsLinks,
    this.websiteUri,
    this.nationalPhoneNumber,
    this.internationalPhoneNumber,
    this.rating,
    this.userRatingCount,
    this.priceLevel,
    this.priceRange,
    this.businessStatus,
    this.openingDate,
    this.attributions = const <PlaceAttribution>[],
    this.iconMaskBaseUri,
    this.iconBackgroundColor,
    this.utcOffsetMinutes,
    this.delivery,
    this.dineIn,
    this.takeout,
    this.curbsidePickup,
    this.reservable,
    this.servesBreakfast,
    this.servesLunch,
    this.servesDinner,
    this.servesBeer,
    this.servesWine,
    this.servesBrunch,
    this.servesVegetarianFood,
    this.servesCocktails,
    this.servesDessert,
    this.servesCoffee,
    this.outdoorSeating,
    this.liveMusic,
    this.menuForChildren,
    this.allowsDogs,
    this.restroom,
    this.goodForChildren,
    this.goodForGroups,
    this.goodForWatchingSports,
    this.currentOpeningHours,
    this.regularOpeningHours,
    this.currentSecondaryOpeningHours = const <Map<String, Object?>>[],
    this.regularSecondaryOpeningHours = const <Map<String, Object?>>[],
    this.timeZone,
    this.editorialSummary,
    this.paymentOptions,
    this.parkingOptions,
    this.accessibilityOptions,
    this.subDestinations = const <PlaceResourceReference>[],
    this.containingPlaces = const <PlaceResourceReference>[],
    this.addressDescriptor,
    this.evChargeOptions,
    this.fuelOptions,
    this.generativeSummary,
    this.reviewSummary,
    this.evChargeAmenitySummary,
    this.neighborhoodSummary,
    this.consumerAlert,
    this.transitStation,
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

  /// Address formatted using the `adr` microformat.
  final String? adrFormatAddress;

  /// Structured postal-address representation, when requested.
  final PlacePostalAddress? postalAddress;

  /// Structured address components, when requested.
  final List<PlaceAddressComponent> addressComponents;

  /// Open Location Code for this place.
  final PlacePlusCode? plusCode;

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

  /// Localized type label shown for the place on Google Maps.
  final LocalizedText? googleMapsTypeLabel;

  /// Google Maps URI for this place.
  final String? googleMapsUri;

  /// Links to Google Maps actions for this place.
  final PlaceGoogleMapsLinks? googleMapsLinks;

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

  /// Typed price range returned by Google.
  final PlacePriceRange? priceRange;

  /// Business status returned by Google.
  final String? businessStatus;

  /// Anticipated opening date for a future-opening business.
  final PlaceDate? openingDate;

  /// Data-provider attributions that must be displayed with this place.
  final List<PlaceAttribution> attributions;

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

  /// Whether curbside pickup is available.
  final bool? curbsidePickup;

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

  /// Whether brunch is served.
  final bool? servesBrunch;

  /// Whether vegetarian food is served.
  final bool? servesVegetarianFood;

  /// Whether cocktails are served.
  final bool? servesCocktails;

  /// Whether dessert is served.
  final bool? servesDessert;

  /// Whether coffee is served.
  final bool? servesCoffee;

  /// Whether outdoor seating is available.
  final bool? outdoorSeating;

  /// Whether live music is available.
  final bool? liveMusic;

  /// Whether a children's menu is available.
  final bool? menuForChildren;

  /// Whether dogs are allowed.
  final bool? allowsDogs;

  /// Whether restrooms are available.
  final bool? restroom;

  /// Whether the place is good for children.
  final bool? goodForChildren;

  /// Whether the place is good for groups.
  final bool? goodForGroups;

  /// Whether the place is suitable for watching sports.
  final bool? goodForWatchingSports;

  /// Current opening-hours payload returned by Google.
  final Map<String, Object?>? currentOpeningHours;

  /// Regular opening-hours payload returned by Google.
  final Map<String, Object?>? regularOpeningHours;

  /// Current secondary opening-hours payloads, deeply immutable.
  final List<Map<String, Object?>> currentSecondaryOpeningHours;

  /// Regular secondary opening-hours payloads, deeply immutable.
  final List<Map<String, Object?>> regularSecondaryOpeningHours;

  /// IANA time-zone identity embedded in the place resource.
  final PlaceTimeZone? timeZone;

  /// Editorial summary that must be displayed without modification.
  final LocalizedText? editorialSummary;

  /// Payment methods accepted by the place.
  final PlacePaymentOptions? paymentOptions;

  /// Parking options offered by the place.
  final PlaceParkingOptions? parkingOptions;

  /// Wheelchair accessibility options offered by the place.
  final PlaceAccessibilityOptions? accessibilityOptions;

  /// Specific destinations associated with this place.
  final List<PlaceResourceReference> subDestinations;

  /// Places that contain this place.
  final List<PlaceResourceReference> containingPlaces;

  /// Address descriptor payload returned by Google, when available.
  final Map<String, Object?>? addressDescriptor;

  /// EV charging options payload returned by Google, when available.
  final Map<String, Object?>? evChargeOptions;

  /// Fuel options payload returned by Google, when available.
  final Map<String, Object?>? fuelOptions;

  /// AI-generated place summary payload returned by Google, when requested.
  final Map<String, Object?>? generativeSummary;

  /// AI-generated review summary payload, deeply immutable.
  final Map<String, Object?>? reviewSummary;

  /// AI-generated nearby EV amenity summary payload, deeply immutable.
  final Map<String, Object?>? evChargeAmenitySummary;

  /// AI-generated neighborhood summary payload, deeply immutable.
  final Map<String, Object?>? neighborhoodSummary;

  /// Consumer alert payload, deeply immutable.
  final Map<String, Object?>? consumerAlert;

  /// Transit station data for this place.
  final PlaceTransitStation? transitStation;

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

  /// Typed representation of [priceLevel], when Google returns a known value.
  ///
  /// [priceLevel] remains available as its original string for source
  /// compatibility and forward compatibility with future Google values.
  PlacePriceLevel? get priceLevelValue {
    final value = priceLevel;
    if (value == null) {
      return null;
    }
    for (final level in PlacePriceLevel.values) {
      if (level.restName == value ||
          level.restName.replaceFirst('PRICE_LEVEL_', '') ==
              value.toUpperCase()) {
        return level;
      }
    }
    return null;
  }

  factory PlaceData.fromJson(Map<String, Object?> json) => PlaceData(
    id: (json['id'] ?? '') as String,
    resourceName: json['name'] as String?,
    displayName: json['displayName'] == null
        ? null
        : LocalizedText.fromJson(json['displayName']),
    formattedAddress: json['formattedAddress'] as String?,
    shortFormattedAddress: json['shortFormattedAddress'] as String?,
    adrFormatAddress: json['adrFormatAddress'] as String?,
    postalAddress: (json['postalAddress'] as Map<Object?, Object?>?) == null
        ? null
        : PlacePostalAddress.fromJson(
            (json['postalAddress'] as Map<Object?, Object?>)
                .cast<String, Object?>(),
          ),
    addressComponents: List<PlaceAddressComponent>.unmodifiable(
      ((json['addressComponents'] as List?) ?? <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (component) => PlaceAddressComponent.fromJson(
              component.cast<String, Object?>(),
            ),
          ),
    ),
    plusCode: json['plusCode'] == null
        ? null
        : PlacePlusCode.fromJson(json['plusCode']),
    location: _parseCoordinates(json['location']),
    viewport: _parseViewport(json['viewport']),
    types: List<String>.unmodifiable(
      ((json['types'] as List?) ?? <Object?>[]).whereType<String>(),
    ),
    primaryType: json['primaryType'] as String?,
    primaryTypeDisplayName: json['primaryTypeDisplayName'] == null
        ? null
        : LocalizedText.fromJson(json['primaryTypeDisplayName']),
    googleMapsTypeLabel: json['googleMapsTypeLabel'] == null
        ? null
        : LocalizedText.fromJson(json['googleMapsTypeLabel']),
    googleMapsUri: json['googleMapsUri'] as String?,
    googleMapsLinks: json['googleMapsLinks'] == null
        ? null
        : PlaceGoogleMapsLinks.fromJson(json['googleMapsLinks']),
    websiteUri: json['websiteUri'] as String?,
    nationalPhoneNumber: json['nationalPhoneNumber'] as String?,
    internationalPhoneNumber: json['internationalPhoneNumber'] as String?,
    rating: _toDouble(json['rating']),
    userRatingCount: (json['userRatingCount'] as num?)?.toInt(),
    priceLevel: json['priceLevel'] as String?,
    priceRange: json['priceRange'] == null
        ? null
        : PlacePriceRange.fromJson(json['priceRange']),
    businessStatus: json['businessStatus'] as String?,
    openingDate: json['openingDate'] == null
        ? null
        : PlaceDate.fromJson(json['openingDate']),
    attributions: List<PlaceAttribution>.unmodifiable(
      _jsonList(json['attributions']).map(PlaceAttribution.fromJson),
    ),
    iconMaskBaseUri: json['iconMaskBaseUri'] as String?,
    iconBackgroundColor: json['iconBackgroundColor'] as String?,
    utcOffsetMinutes: (json['utcOffsetMinutes'] as num?)?.toInt(),
    delivery: json['delivery'] as bool?,
    dineIn: json['dineIn'] as bool?,
    takeout: json['takeout'] as bool?,
    curbsidePickup: json['curbsidePickup'] as bool?,
    reservable: json['reservable'] as bool?,
    servesBreakfast: json['servesBreakfast'] as bool?,
    servesLunch: json['servesLunch'] as bool?,
    servesDinner: json['servesDinner'] as bool?,
    servesBeer: json['servesBeer'] as bool?,
    servesWine: json['servesWine'] as bool?,
    servesBrunch: json['servesBrunch'] as bool?,
    servesVegetarianFood: json['servesVegetarianFood'] as bool?,
    servesCocktails: json['servesCocktails'] as bool?,
    servesDessert: json['servesDessert'] as bool?,
    servesCoffee: json['servesCoffee'] as bool?,
    outdoorSeating: json['outdoorSeating'] as bool?,
    liveMusic: json['liveMusic'] as bool?,
    menuForChildren: json['menuForChildren'] as bool?,
    allowsDogs: json['allowsDogs'] as bool?,
    restroom: json['restroom'] as bool?,
    goodForChildren: json['goodForChildren'] as bool?,
    goodForGroups: json['goodForGroups'] as bool?,
    goodForWatchingSports: json['goodForWatchingSports'] as bool?,
    currentOpeningHours: _deepImmutableJsonMap(json['currentOpeningHours']),
    regularOpeningHours: _deepImmutableJsonMap(json['regularOpeningHours']),
    currentSecondaryOpeningHours: _deepImmutableJsonMapList(
      json['currentSecondaryOpeningHours'],
    ),
    regularSecondaryOpeningHours: _deepImmutableJsonMapList(
      json['regularSecondaryOpeningHours'],
    ),
    timeZone: json['timeZone'] == null
        ? null
        : PlaceTimeZone.fromJson(json['timeZone']),
    editorialSummary: json['editorialSummary'] == null
        ? null
        : LocalizedText.fromJson(json['editorialSummary']),
    paymentOptions: json['paymentOptions'] == null
        ? null
        : PlacePaymentOptions.fromJson(json['paymentOptions']),
    parkingOptions: json['parkingOptions'] == null
        ? null
        : PlaceParkingOptions.fromJson(json['parkingOptions']),
    accessibilityOptions: json['accessibilityOptions'] == null
        ? null
        : PlaceAccessibilityOptions.fromJson(json['accessibilityOptions']),
    subDestinations: List<PlaceResourceReference>.unmodifiable(
      _jsonList(json['subDestinations']).map(PlaceResourceReference.fromJson),
    ),
    containingPlaces: List<PlaceResourceReference>.unmodifiable(
      _jsonList(json['containingPlaces']).map(PlaceResourceReference.fromJson),
    ),
    addressDescriptor: _deepImmutableJsonMap(json['addressDescriptor']),
    evChargeOptions: _deepImmutableJsonMap(json['evChargeOptions']),
    fuelOptions: _deepImmutableJsonMap(json['fuelOptions']),
    generativeSummary: _deepImmutableJsonMap(json['generativeSummary']),
    reviewSummary: _deepImmutableJsonMap(json['reviewSummary']),
    evChargeAmenitySummary: _deepImmutableJsonMap(
      json['evChargeAmenitySummary'],
    ),
    neighborhoodSummary: _deepImmutableJsonMap(json['neighborhoodSummary']),
    consumerAlert: _deepImmutableJsonMap(json['consumerAlert']),
    transitStation: json['transitStation'] == null
        ? null
        : PlaceTransitStation.fromJson(json['transitStation']),
    pureServiceAreaBusiness: json['pureServiceAreaBusiness'] as bool?,
    movedPlace: json['movedPlace'] as String?,
    movedPlaceId: json['movedPlaceId'] as String?,
    reviews: List<PlaceReview>.unmodifiable(
      ((json['reviews'] as List?) ?? <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map(
            (review) => PlaceReview.fromJson(review.cast<String, Object?>()),
          ),
    ),
    photos: List<PlacePhoto>.unmodifiable(
      ((json['photos'] as List?) ?? <Object?>[])
          .whereType<Map<Object?, Object?>>()
          .map((photo) => PlacePhoto.fromJson(photo.cast<String, Object?>())),
    ),
    rawData: _deepImmutableJsonMap(json)!,
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
    this.includeFutureOpeningBusinesses = false,
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

  /// Whether businesses expected to open in the future should be included.
  final bool includeFutureOpeningBusinesses;

  /// Whether query predictions should be included alongside place predictions.
  ///
  /// [PlacesClient.autocomplete] keeps returning only [PlaceSuggestion] values.
  /// Use [PlacesClient.autocompleteSuggestions] to receive both place and
  /// query suggestions.
  final bool includeQueryPredictions;

  /// Validates request invariants before serialization.
  void validate() {
    if (input.trim().isEmpty) {
      throw const PlacesException.validation(
        'Autocomplete input cannot be empty.',
        operation: PlacesOperation.autocomplete,
        code: 'empty_autocomplete_input',
      );
    }
    if (locationBias != null && locationRestriction != null) {
      throw const PlacesException.validation(
        'locationBias and locationRestriction cannot be set together.',
        operation: PlacesOperation.autocomplete,
        code: 'conflicting_location_filters',
      );
    }
    if (inputOffset != null &&
        (inputOffset! < 0 || inputOffset! > input.runes.length)) {
      throw const PlacesException.validation(
        'inputOffset must be a Unicode character offset inside input.',
        operation: PlacesOperation.autocomplete,
        code: 'invalid_input_offset',
      );
    }
    if (includedPrimaryTypes.length > 5) {
      throw const PlacesException.validation(
        'includedPrimaryTypes supports at most five values.',
        operation: PlacesOperation.autocomplete,
        code: 'too_many_primary_types',
      );
    }
    _validateNonEmptyValues(
      includedPrimaryTypes,
      name: 'includedPrimaryTypes',
      operation: PlacesOperation.autocomplete,
    );
    final collections = includedPrimaryTypes
        .where((type) => type == '(cities)' || type == '(regions)')
        .toList(growable: false);
    if (collections.isNotEmpty && includedPrimaryTypes.length != 1) {
      throw const PlacesException.validation(
        '(cities) and (regions) cannot be combined with other primary types.',
        operation: PlacesOperation.autocomplete,
        code: 'conflicting_primary_types',
      );
    }
    if (includedRegionCodes.length > 15 ||
        includedRegionCodes.any(
          (code) => !RegExp(r'^[A-Za-z]{2}$').hasMatch(code),
        )) {
      throw const PlacesException.validation(
        'includedRegionCodes supports up to 15 two-letter region codes.',
        operation: PlacesOperation.autocomplete,
        code: 'invalid_region_codes',
      );
    }
    origin?.validate(operation: PlacesOperation.autocomplete);
    _validateArea(locationBias?.area, operation: PlacesOperation.autocomplete);
    _validateArea(
      locationRestriction?.area,
      operation: PlacesOperation.autocomplete,
    );
    sessionToken?.validate(operation: PlacesOperation.autocomplete);
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
      if (includeFutureOpeningBusinesses)
        'includeFutureOpeningBusinesses': true,
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

  /// Validates the place identifier, field mask, and optional session token.
  void validate() {
    if (placeId.trim().isEmpty) {
      throw const PlacesException.validation(
        'Place Details requires a non-empty placeId.',
        operation: PlacesOperation.placeDetails,
        code: 'empty_place_id',
      );
    }
    _validateFields(fields, operation: PlacesOperation.placeDetails);
    sessionToken?.validate(operation: PlacesOperation.placeDetails);
  }

  /// Comma-separated field mask for Google Place Details requests.
  String get detailsFieldMask {
    validate();
    return fields.map((field) => field.apiName).join(',');
  }
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

  /// Validates coordinates before a Time Zone request is sent.
  void validate() => location.validate(operation: PlacesOperation.timeZone);

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
      throw const PlacesException.validation(
        'Time zone lookup requires place details with location coordinates.',
        operation: PlacesOperation.timeZone,
        code: 'missing_place_location',
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
    this.pageSize,
    this.pageToken,
    this.priceLevels = const <PlacePriceLevel>[],
    this.includePureServiceAreaBusinesses = false,
    this.includeFutureOpeningBusinesses = false,
    @Deprecated(
      'Use pageSize instead. maxResultCount is deprecated in 0.6.0 and will '
      'be removed in 1.0.0.',
    )
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

  /// Maximum number of results requested per page.
  final int? pageSize;

  /// Token returned by a previous [TextSearchPage] for the next page.
  final String? pageToken;

  /// Price levels to include in the results.
  ///
  /// [PlacePriceLevel.free] and [PlacePriceLevel.unspecified] cannot be used as
  /// request filters.
  final List<PlacePriceLevel> priceLevels;

  /// Whether pure service-area businesses should be included in results.
  final bool includePureServiceAreaBusinesses;

  /// Whether businesses expected to open in the future should be included.
  final bool includeFutureOpeningBusinesses;

  /// Maximum number of results requested from Google.
  ///
  /// Deprecated in 0.6.0. Use [pageSize] instead. When both are supplied,
  /// Google ignores this value and uses [pageSize].
  @Deprecated(
    'Use pageSize instead. maxResultCount is deprecated in 0.6.0 and will '
    'be removed in 1.0.0.',
  )
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
      throw const PlacesException.validation(
        'Text search query cannot be empty.',
        operation: PlacesOperation.textSearch,
        code: 'empty_text_query',
      );
    }
    if (locationBias != null && locationRestriction != null) {
      throw const PlacesException.validation(
        'locationBias and locationRestriction cannot be set together.',
        operation: PlacesOperation.textSearch,
        code: 'conflicting_location_filters',
      );
    }
    if (priceLevels.contains(PlacePriceLevel.unspecified) ||
        priceLevels.contains(PlacePriceLevel.free)) {
      throw const PlacesException.validation(
        'Text search priceLevels cannot contain unspecified or free.',
        operation: PlacesOperation.textSearch,
        code: 'invalid_price_level',
      );
    }
    _validateFields(fields, operation: PlacesOperation.textSearch);
    if (includedType != null && includedType!.trim().isEmpty) {
      throw const PlacesException.validation(
        'includedType cannot be empty when supplied.',
        operation: PlacesOperation.textSearch,
        code: 'empty_included_type',
      );
    }
    if (pageSize != null && (pageSize! < 1 || pageSize! > 20)) {
      throw const PlacesException.validation(
        'pageSize must be between 1 and 20.',
        operation: PlacesOperation.textSearch,
        code: 'invalid_page_size',
      );
    }
    // ignore: deprecated_member_use_from_same_package
    if (maxResultCount != null &&
        // ignore: deprecated_member_use_from_same_package
        (maxResultCount! < 1 || maxResultCount! > 20)) {
      throw const PlacesException.validation(
        'maxResultCount must be between 1 and 20.',
        operation: PlacesOperation.textSearch,
        code: 'invalid_max_result_count',
      );
    }
    if (pageToken != null && pageToken!.trim().isEmpty) {
      throw const PlacesException.validation(
        'pageToken cannot be empty when supplied.',
        operation: PlacesOperation.textSearch,
        code: 'empty_page_token',
      );
    }
    if (minRating != null &&
        (!minRating!.isFinite || minRating! < 0 || minRating! > 5)) {
      throw const PlacesException.validation(
        'minRating must be finite and between 0 and 5.',
        operation: PlacesOperation.textSearch,
        code: 'invalid_min_rating',
      );
    }
    _validateArea(locationBias?.area, operation: PlacesOperation.textSearch);
    if (locationRestriction?.area case final area?) {
      if (area is! RectangleArea) {
        throw const PlacesException.validation(
          'Text Search locationRestriction must be a rectangle.',
          operation: PlacesOperation.textSearch,
          code: 'invalid_location_restriction_shape',
        );
      }
      _validateArea(area, operation: PlacesOperation.textSearch);
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
      if (pageSize != null) 'pageSize': pageSize,
      if (pageToken != null) 'pageToken': pageToken,
      if (priceLevels.isNotEmpty)
        'priceLevels': priceLevels.map((level) => level.restName).toList(),
      if (includePureServiceAreaBusinesses)
        'includePureServiceAreaBusinesses': true,
      if (includeFutureOpeningBusinesses)
        'includeFutureOpeningBusinesses': true,
      // ignore: deprecated_member_use_from_same_package
      if (maxResultCount != null) 'maxResultCount': maxResultCount,
      if (minRating != null) 'minRating': minRating,
      if (openNow != null) 'openNow': openNow,
      'rankPreference': rankPreference.restName,
    };
  }
}

@immutable
/// One page returned by Places Text Search (New).
class TextSearchPage {
  /// Creates an immutable text-search page.
  TextSearchPage({
    required List<PlaceData> results,
    this.nextPageToken,
    this.searchUri,
  }) : results = List<PlaceData>.unmodifiable(results);

  /// Places returned for this page.
  final List<PlaceData> results;

  /// Token to pass to [TextSearchRequest.pageToken] for the next page.
  final String? nextPageToken;

  /// Google Maps URI representing the same text search, when returned.
  final String? searchUri;

  /// Whether Google reported another page of results.
  bool get hasNextPage => nextPageToken?.isNotEmpty ?? false;

  /// Parses a Text Search response payload.
  factory TextSearchPage.fromJson(Map<String, Object?> json) {
    final results = ((json['places'] as List?) ?? <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((item) => PlaceData.fromJson(item.cast<String, Object?>()))
        .toList(growable: false);
    return TextSearchPage(
      results: results,
      nextPageToken: json['nextPageToken'] as String?,
      searchUri: json['searchUri'] as String?,
    );
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
    this.includeFutureOpeningBusinesses = false,
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

  /// Whether businesses expected to open in the future should be included.
  final bool includeFutureOpeningBusinesses;

  /// Ranking behavior for nearby results.
  final SearchNearbyRankPreference rankPreference;

  /// Validates documented Nearby Search limits and filter conflicts.
  void validate() {
    _validateFields(fields, operation: PlacesOperation.nearbySearch);
    final area = locationRestriction.area;
    if (area is! CircleArea) {
      throw const PlacesException.validation(
        'Nearby Search locationRestriction must be a circle.',
        operation: PlacesOperation.nearbySearch,
        code: 'invalid_location_restriction_shape',
      );
    }
    _validateArea(
      area,
      operation: PlacesOperation.nearbySearch,
      requirePositiveRadius: true,
    );
    for (final entry in <(String, List<String>)>[
      ('includedTypes', includedTypes),
      ('excludedTypes', excludedTypes),
      ('includedPrimaryTypes', includedPrimaryTypes),
      ('excludedPrimaryTypes', excludedPrimaryTypes),
    ]) {
      if (entry.$2.length > 50) {
        throw PlacesException.validation(
          '${entry.$1} supports at most 50 values.',
          operation: PlacesOperation.nearbySearch,
          code: 'too_many_types',
        );
      }
      _validateNonEmptyValues(
        entry.$2,
        name: entry.$1,
        operation: PlacesOperation.nearbySearch,
      );
    }
    if (includedTypes.toSet().intersection(excludedTypes.toSet()).isNotEmpty ||
        includedPrimaryTypes
            .toSet()
            .intersection(excludedPrimaryTypes.toSet())
            .isNotEmpty) {
      throw const PlacesException.validation(
        'Nearby Search include and exclude filters cannot conflict.',
        operation: PlacesOperation.nearbySearch,
        code: 'conflicting_type_filters',
      );
    }
    if (maxResultCount != null &&
        (maxResultCount! < 1 || maxResultCount! > 20)) {
      throw const PlacesException.validation(
        'Nearby Search maxResultCount must be between 1 and 20.',
        operation: PlacesOperation.nearbySearch,
        code: 'invalid_max_result_count',
      );
    }
  }

  /// Field mask used for nearby search requests.
  String get searchFieldMask =>
      fields.map((field) => field.searchMaskPath).join(',');

  /// Serializes the request for the Places nearby-search endpoint.
  Map<String, Object?> toRestJson() {
    validate();
    return <String, Object?>{
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
      if (includeFutureOpeningBusinesses)
        'includeFutureOpeningBusinesses': true,
      'rankPreference': rankPreference.restName,
    };
  }
}

bool _validPhotoDimension(int? value) =>
    value == null || (value >= 1 && value <= 4800);

void _validateFields(
  Set<PlaceField> fields, {
  required PlacesOperation operation,
}) {
  if (fields.isEmpty) {
    throw PlacesException.validation(
      'At least one Place field must be requested.',
      operation: operation,
      code: 'empty_field_mask',
    );
  }
}

void _validateNonEmptyValues(
  Iterable<String> values, {
  required String name,
  required PlacesOperation operation,
}) {
  if (values.any((value) => value.trim().isEmpty)) {
    throw PlacesException.validation(
      '$name cannot contain empty values.',
      operation: operation,
      code: 'empty_filter_value',
    );
  }
}

void _validateArea(
  PlacesArea? area, {
  required PlacesOperation operation,
  bool requirePositiveRadius = false,
}) {
  switch (area) {
    case null:
      return;
    case CircleArea():
      area.center.validate(operation: operation);
      if (!area.radiusMeters.isFinite ||
          (requirePositiveRadius
              ? area.radiusMeters <= 0
              : area.radiusMeters < 0) ||
          area.radiusMeters > 50000) {
        throw PlacesException.validation(
          requirePositiveRadius
              ? 'Circle radius must be greater than 0 and at most 50000 meters.'
              : 'Circle radius must be between 0 and 50000 meters.',
          operation: operation,
          code: 'invalid_circle_radius',
        );
      }
      return;
    case RectangleArea():
      area.low.validate(operation: operation);
      area.high.validate(operation: operation);
      final fullLongitude =
          area.low.longitude == -180 && area.high.longitude == 180;
      final longitudeSpan = area.low.longitude <= area.high.longitude
          ? area.high.longitude - area.low.longitude
          : 360 - (area.low.longitude - area.high.longitude);
      if (area.low.latitude >= area.high.latitude ||
          area.low.longitude == area.high.longitude ||
          (area.low.longitude == 180 && area.high.longitude == -180) ||
          (!fullLongitude && longitudeSpan > 180)) {
        throw PlacesException.validation(
          'Rectangle bounds must describe a non-empty viewport.',
          operation: operation,
          code: 'invalid_rectangle',
        );
      }
      return;
  }
}

Map<String, Object?>? _jsonMap(Object? source) {
  if (source is! Map<Object?, Object?>) {
    return null;
  }
  return source.cast<String, Object?>();
}

List<Object?> _jsonList(Object? source) {
  if (source is! List<Object?>) {
    return const <Object?>[];
  }
  return source;
}

Object? _deepImmutableJson(Object? source) {
  if (source is Map<Object?, Object?>) {
    return Map<String, Object?>.unmodifiable(
      source.map(
        (key, value) => MapEntry(key.toString(), _deepImmutableJson(value)),
      ),
    );
  }
  if (source is List<Object?>) {
    return List<Object?>.unmodifiable(source.map(_deepImmutableJson));
  }
  return source;
}

Map<String, Object?>? _deepImmutableJsonMap(Object? source) {
  final value = _deepImmutableJson(source);
  return value is Map<String, Object?> ? value : null;
}

List<Map<String, Object?>> _deepImmutableJsonMapList(Object? source) {
  return List<Map<String, Object?>>.unmodifiable(
    _jsonList(source).map(_deepImmutableJsonMap).whereType(),
  );
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
