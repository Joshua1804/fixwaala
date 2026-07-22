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

  // OTP
  static const int otpLength = 6;
  static const int otpResendSeconds = 30;

  // Simulated payment
  static const double platformFeePercent = 0.05;
}
