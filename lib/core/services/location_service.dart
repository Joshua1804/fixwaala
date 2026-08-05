import 'dart:math' as math;

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart' as geolocator;

import '../models/user_model.dart';

/// Wraps device location + geocoding for the customer & provider apps.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  static const double _earthRadiusKm = 6371.0;

  Future<bool> requestPermission() async {
    if (!await geolocator.Geolocator.isLocationServiceEnabled()) {
      return false;
    }
    var permission = await geolocator.Geolocator.checkPermission();
    if (permission == geolocator.LocationPermission.denied) {
      permission = await geolocator.Geolocator.requestPermission();
    }
    return permission == geolocator.LocationPermission.always ||
        permission == geolocator.LocationPermission.whileInUse;
  }

  Future<GeoPoint?> getCurrentLocation() async {
    if (!await requestPermission()) return null;
    try {
      final position = await geolocator.Geolocator.getCurrentPosition(
        locationSettings: const geolocator.LocationSettings(
          accuracy: geolocator.LocationAccuracy.high,
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (_) {
      return null;
    }
  }

  Stream<GeoPoint> watchProviderLocation() {
    const settings = geolocator.LocationSettings(
      accuracy: geolocator.LocationAccuracy.high,
      distanceFilter: 10,
    );
    return geolocator.Geolocator.getPositionStream(
      locationSettings: settings,
    ).map((position) => GeoPoint(position.latitude, position.longitude));
  }

  double distanceKm(GeoPoint a, GeoPoint b) {
    final lat1 = _degToRad(a.latitude);
    final lat2 = _degToRad(b.latitude);
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);

    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
    return _earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  Future<String?> reverseGeocode(GeoPoint point) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      if (placemarks.isEmpty) return null;
      final p = placemarks.first;
      final parts = [
        p.street,
        p.subLocality,
        p.locality,
        p.administrativeArea,
        p.postalCode,
      ].where((part) => part != null && part.trim().isNotEmpty);
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null;
    }
  }
}
