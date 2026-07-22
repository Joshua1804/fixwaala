import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../models/provider_match.dart';

/// Expanding-radius broadcast: notifies eligible providers in a 5→10→15 km ring.
class GeoBroadcastService {
  GeoBroadcastService._();
  static final GeoBroadcastService instance = GeoBroadcastService._();

  Future<List<ProviderCandidate>> findEligibleProviders({
    required GeoPoint origin,
    required ServiceCategory category,
    required double radiusKm,
  }) async {
    // TODO: geoquery Firestore + filter by:
    //   • skill == category
    //   • verified == true
    //   • availability == online
    //   • account status == active
    //   • location updated within AppConstants.locationFreshnessSeconds
    return const [];
  }

  Future<void> notifyProviders(List<ProviderCandidate> providers, String ticketId) async {
    // TODO: send FCM to each provider with ticket details (no exact address).
  }

  /// Emits candidates in expanding radii until one accepts, or fails.
  Stream<List<ProviderCandidate>> runBroadcast({
    required GeoPoint origin,
    required ServiceCategory category,
    required String ticketId,
  }) async* {
    for (final radius in AppConstants.searchRadiiKm) {
      final providers = await findEligibleProviders(
        origin: origin,
        category: category,
        radiusKm: radius,
      );
      await notifyProviders(providers, ticketId);
      yield providers;
      await Future.delayed(
        Duration(seconds: AppConstants.broadcastTimeoutSeconds),
      );
    }
  }
}
