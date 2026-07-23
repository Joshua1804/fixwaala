class AppConstants {
  AppConstants._();

  static const String appName = 'Fixwaala';

  // Trust-gated matching (Module 6)
  static const int candidateReviewSeconds = 30;

  // Geo-broadcast (Module 5)
  static const List<double> searchRadiiKm = [5, 10, 15];
  static const int broadcastTimeoutSeconds = 120;

  // Location freshness threshold (seconds) for eligible providers
  static const int locationFreshnessSeconds = 120;

  // Simulated payment
  static const double platformFeePercent = 0.05;

  // Demo admin credentials (used only when Firebase is not configured).
  static const String demoAdminEmail = 'admin@fixwaala.com';
  static const String demoAdminPassword = 'admin123';

  // Trust score weighting (Module 10) — must sum to 1.0.
  static const double trustWeightRating = 0.40;
  static const double trustWeightCompletion = 0.30;
  static const double trustWeightResponse = 0.15;
  static const double trustWeightCancellation = 0.15;

  // Response time beyond this is treated as the worst case (0 score).
  static const int trustMaxAcceptableResponseSeconds = 300;

  // Demo provider identity shared between Trust-Gated Matching's stubbed
  // candidate card (Module 6, not yet wired to real candidate data) and the
  // Service Job Lifecycle provider screens (Module 7), so a single-device
  // walkthrough can be demonstrated end-to-end. Replace with the real
  // provider's id/name once Module 6 threads a ProviderCandidate through.
  static const String demoProviderId = 'demo-provider-001';
  static const String demoProviderName = 'Rajesh Kumar';
}
