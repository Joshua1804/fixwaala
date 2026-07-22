import '../models/user_model.dart';

/// Wraps device location + geocoding for the customer & provider apps.
///
/// Skeleton — plug in `geolocator` and `geocoding` when the packages are added.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<bool> requestPermission() async {
    // TODO: request runtime location permissions.
    return true;
  }

  Future<GeoPoint?> getCurrentLocation() async {
    // TODO: geolocator.getCurrentPosition(...)
    return null;
  }

  Stream<GeoPoint> watchProviderLocation() async* {
    // TODO: geolocator.getPositionStream(...)
  }

  double distanceKm(GeoPoint a, GeoPoint b) {
    // TODO: replace with proper haversine calculation.
    return 0;
  }

  Future<String?> reverseGeocode(GeoPoint point) async {
    // TODO: `geocoding.placemarkFromCoordinates`
    return null;
  }
}
