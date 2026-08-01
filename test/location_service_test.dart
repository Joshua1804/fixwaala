import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/user_model.dart';
import 'package:fixwaala/core/services/location_service.dart';

void main() {
  group('LocationService.distanceKm', () {
    test('is zero for the same point', () {
      const point = GeoPoint(12.9716, 77.5946);
      expect(
        LocationService.instance.distanceKm(point, point),
        closeTo(0, 0.001),
      );
    });

    test('matches a known great-circle distance (Bengaluru to Chennai)', () {
      const bengaluru = GeoPoint(12.9716, 77.5946);
      const chennai = GeoPoint(13.0827, 80.2707);
      final distance = LocationService.instance.distanceKm(bengaluru, chennai);
      // Real-world distance is ~290 km; allow a generous tolerance.
      expect(distance, greaterThan(280));
      expect(distance, lessThan(300));
    });

    test('is symmetric', () {
      const delhi = GeoPoint(28.6139, 77.2090);
      const mumbai = GeoPoint(19.0760, 72.8777);
      final forward = LocationService.instance.distanceKm(delhi, mumbai);
      final backward = LocationService.instance.distanceKm(mumbai, delhi);
      expect(forward, closeTo(backward, 0.0001));
    });
  });
}
