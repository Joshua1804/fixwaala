class AppConstants {
  AppConstants._();

  static const String appName = 'Fixwaala';

  // Trust-gated matching (Module 6)
  //
  // The customer has to open a provider's profile, read their reviews, and
  // decide. Thirty seconds was not enough for a decision about who to let
  // into their home — and the window is now enforced server-side
  // (functions/scheduled.js), so it keeps running when the screen is closed.
  static const int candidateReviewSeconds = 180;

  /// Warn the customer when this little time is left.
  static const int candidateReviewWarningSeconds = 30;

  // Geo-broadcast (Module 5)
  static const List<double> searchRadiiKm = [5, 10, 15];
  static const int broadcastTimeoutSeconds = 120;

  // Location freshness threshold (seconds) for eligible providers
  static const int locationFreshnessSeconds = 120;

  // Simulated payment
  static const double platformFeePercent = 0.05;

  // Trust score weighting (Module 10) — must sum to 1.0.
  static const double trustWeightRating = 0.40;
  static const double trustWeightCompletion = 0.30;
  static const double trustWeightResponse = 0.15;
  static const double trustWeightCancellation = 0.15;

  // Response time beyond this is treated as the worst case (0 score).
  static const int trustMaxAcceptableResponseSeconds = 300;

  /// Whether `expandBroadcastRadius` and `expireCandidateLeases`
  /// (`functions/scheduled.js`) are actually deployed and running.
  ///
  /// Both require the project to be on the Blaze plan — Cloud Functions v2
  /// runs on Cloud Run, which needs a billing account attached regardless of
  /// usage. Defaults to `false` so the client-side fallback timers in
  /// [GeoBroadcastService] and `ProviderReviewScreen` do the job themselves;
  /// flip it with `--dart-define=SCHEDULED_FUNCTIONS_DEPLOYED=true` once the
  /// scheduled functions are live, so the two stop racing each other.
  static const bool scheduledFunctionsDeployed = bool.fromEnvironment(
    'SCHEDULED_FUNCTIONS_DEPLOYED',
  );

  // Demo provider identity shared between Trust-Gated Matching's stubbed
  // candidate card (Module 6, not yet wired to real candidate data) and the
  // Service Job Lifecycle provider screens (Module 7), so a single-device
  // walkthrough can be demonstrated end-to-end. Replace with the real
  // provider's id/name once Module 6 threads a ProviderCandidate through.
  static const String demoProviderId = 'demo-provider-001';
  static const String demoProviderName = 'Rajesh Kumar';
}
