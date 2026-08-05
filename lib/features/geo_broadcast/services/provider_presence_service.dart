import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:flutter/foundation.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../../trust_gated_matching/services/matching_service.dart';

/// Owns a provider's online/offline status and live location, embedded on
/// their `users/{uid}` doc under `providerProfile` (Module 5).
///
/// Mirrors [JobService]'s live-Firestore-listener template: writes go
/// through [AuthService.updateProviderProfile], reads for the customer's
/// own device come from a `.snapshots()` stream on the provider's doc. In
/// simulation mode (no Firebase configured) an in-memory broadcast stream
/// stands in for Firestore so the two-sided demo still works.
class ProviderPresenceService {
  ProviderPresenceService._();
  static final ProviderPresenceService instance = ProviderPresenceService._();

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      FirebaseService.instance.firestore.collection('users');

  StreamSubscription<GeoPoint>? _shareSub;
  final Map<String, GeoPoint> _simLocations = {};
  final StreamController<MapEntry<String, GeoPoint>> _simController =
      StreamController<MapEntry<String, GeoPoint>>.broadcast();

  /// Clears all in-memory state. Test-only.
  @visibleForTesting
  Future<void> resetForTesting() async {
    await _shareSub?.cancel();
    _shareSub = null;
    _simLocations.clear();
  }

  Future<void> setOnline(bool online) async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final profile = (user.providerProfile ?? const ProviderProfile()).copyWith(
      online: online,
    );
    await AuthService.instance.updateProviderProfile(profile);

    if (online) {
      // Rehydrate past declines before the feed opens, so a restart does not
      // resurface every opportunity this provider already refused.
      await MatchingService.instance.loadDeclines(user.id);
      await updateLocationOnce();
      startSharing();
    } else {
      await stopSharing();
    }
  }

  Future<void> updateLocationOnce() async {
    final location = await LocationService.instance.getCurrentLocation();
    if (location == null) return;
    await _writeLocation(location);
  }

  void startSharing() {
    _shareSub?.cancel();
    _shareSub = LocationService.instance.watchProviderLocation().listen(
      _writeLocation,
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('[ProviderPresenceService] location stream error: $e');
        }
      },
    );
  }

  Future<void> stopSharing() async {
    await _shareSub?.cancel();
    _shareSub = null;
  }

  Future<void> _writeLocation(GeoPoint location) async {
    final user = await AuthService.instance.currentUser();
    if (user == null) return;
    final profile = (user.providerProfile ?? const ProviderProfile()).copyWith(
      liveLocation: location,
      locationUpdatedAt: DateTime.now(),
    );
    await AuthService.instance.updateProviderProfile(profile);

    if (!_live) {
      _simLocations[user.id] = location;
      _simController.add(MapEntry(user.id, location));
    }
  }

  /// Live updates of [providerId]'s location. Emits the last known value
  /// immediately (if any) followed by every subsequent update.
  Stream<GeoPoint> watchProviderLocation(String providerId) async* {
    if (_live) {
      yield* _usersCol
          .doc(providerId)
          .snapshots()
          .handleError((Object e, StackTrace st) {
            if (kDebugMode) {
              debugPrint('[ProviderPresenceService] watch error: $e');
            }
          })
          .where((snap) => snap.exists)
          .expand((snap) {
            final profileMap = snap.data()?['providerProfile'];
            if (profileMap == null) return const <GeoPoint>[];
            final profile = ProviderProfile.fromMap(
              Map<String, dynamic>.from(profileMap as Map),
            );
            final location = profile.liveLocation;
            return location == null ? const <GeoPoint>[] : [location];
          });
    } else {
      final current = _simLocations[providerId];
      if (current != null) yield current;
      yield* _simController.stream
          .where((entry) => entry.key == providerId)
          .map((entry) => entry.value);
    }
  }
}
