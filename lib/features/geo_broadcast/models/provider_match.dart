import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';

class ProviderCandidate {
  final String providerId;
  final String displayName;
  final ServiceCategory category;
  final double distanceKm;
  final int etaMinutes;
  final double ratingAverage;
  final int completedJobs;
  final bool verified;
  final GeoPoint location;
  final String? photoUrl;

  const ProviderCandidate({
    required this.providerId,
    required this.displayName,
    required this.category,
    required this.distanceKm,
    required this.etaMinutes,
    required this.ratingAverage,
    required this.completedJobs,
    required this.verified,
    required this.location,
    this.photoUrl,
  });
}
