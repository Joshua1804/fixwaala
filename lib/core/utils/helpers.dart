import 'dart:math' as math;

import '../models/user_model.dart';

class Helpers {
  Helpers._();

  /// Haversine distance in kilometres.
  static double haversineKm(GeoPoint a, GeoPoint b) {
    const earthKm = 6371.0;
    final dLat = _deg2rad(b.latitude - a.latitude);
    final dLon = _deg2rad(b.longitude - a.longitude);
    final lat1 = _deg2rad(a.latitude);
    final lat2 = _deg2rad(b.latitude);
    final h =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthKm * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _deg2rad(double d) => d * math.pi / 180.0;

  static String formatEtaMinutes(int minutes) =>
      minutes < 60 ? '$minutes min' : '${minutes ~/ 60}h ${minutes % 60}m';
}
