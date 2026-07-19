import '../models/place_models.dart';

/// Maps REST Place field names to their Maps JavaScript Place counterparts.
String webPlaceFieldName(PlaceField field) {
  return switch (field) {
    PlaceField.googleMapsUri => 'googleMapsURI',
    PlaceField.websiteUri => 'websiteURI',
    PlaceField.iconMaskBaseUri => 'svgIconMaskURI',
    PlaceField.delivery => 'hasDelivery',
    PlaceField.dineIn => 'hasDineIn',
    PlaceField.takeout => 'hasTakeout',
    PlaceField.curbsidePickup => 'hasCurbsidePickup',
    PlaceField.reservable => 'isReservable',
    PlaceField.outdoorSeating => 'hasOutdoorSeating',
    PlaceField.liveMusic => 'hasLiveMusic',
    PlaceField.menuForChildren => 'hasMenuForChildren',
    PlaceField.restroom => 'hasRestroom',
    PlaceField.goodForChildren => 'isGoodForChildren',
    PlaceField.goodForGroups => 'isGoodForGroups',
    PlaceField.goodForWatchingSports => 'isGoodForWatchingSports',
    PlaceField.pureServiceAreaBusiness => 'isPureServiceAreaBusiness',
    PlaceField.openingDate => 'futureOpeningDate',
    _ => field.apiName,
  };
}
