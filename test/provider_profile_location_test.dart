import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/user_model.dart';

void main() {
  test('baseLocation and baseAddress round-trip through toMap/fromMap', () {
    const profile = ProviderProfile(
      baseLocation: GeoPoint(12.9716, 77.5946),
      baseAddress: 'Koramangala, Bengaluru',
    );

    final restored = ProviderProfile.fromMap(profile.toMap());

    expect(restored.baseLocation?.latitude, 12.9716);
    expect(restored.baseLocation?.longitude, 77.5946);
    expect(restored.baseAddress, 'Koramangala, Bengaluru');
  });

  test('baseLocation is independent of liveLocation', () {
    const profile = ProviderProfile(
      liveLocation: GeoPoint(1, 1),
      baseLocation: GeoPoint(2, 2),
    );
    final updated = profile.copyWith(liveLocation: const GeoPoint(3, 3));

    expect(updated.liveLocation?.latitude, 3);
    expect(updated.baseLocation?.latitude, 2);
  });
}
