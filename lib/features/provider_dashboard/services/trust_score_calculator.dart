import '../../../core/constants/app_constants.dart';

/// Result of a Trust Score calculation.
///
/// [score] is null when there isn't enough job history yet to produce a
/// meaningful number — screens should show an explanatory empty state
/// rather than a misleading 0.
class TrustScoreResult {
  final double? score; // 0..100
  final String note;

  const TrustScoreResult({required this.score, required this.note});

  bool get hasScore => score != null;
}

/// Pure, deterministic Trust Score calculation (Module 10).
///
/// Weighted from four signals (weights defined in [AppConstants], summing
/// to 1.0): rating average, completion rate, response speed, and
/// cancellation rate. Kept as a standalone pure function so it can be unit
/// tested without touching Firestore or any service singleton.
class TrustScoreCalculator {
  TrustScoreCalculator._();

  static TrustScoreResult calculate({
    required int completedJobs,
    required double ratingAverage, // 0..5
    required double completionRate, // 0..1
    required double cancellationRate, // 0..1
    required int avgResponseSeconds,
  }) {
    if (completedJobs == 0) {
      return const TrustScoreResult(
        score: null,
        note: 'Complete your first job to start building a Trust Score.',
      );
    }

    final ratingComponent =
        (ratingAverage.clamp(0, 5) / 5) * AppConstants.trustWeightRating;
    final completionComponent =
        completionRate.clamp(0, 1) * AppConstants.trustWeightCompletion;

    final responseRatio =
        (avgResponseSeconds / AppConstants.trustMaxAcceptableResponseSeconds)
            .clamp(0, 1);
    final responseComponent =
        (1 - responseRatio) * AppConstants.trustWeightResponse;

    final cancellationComponent =
        (1 - cancellationRate.clamp(0, 1)) *
        AppConstants.trustWeightCancellation;

    final total =
        (ratingComponent +
            completionComponent +
            responseComponent +
            cancellationComponent) *
        100;

    return TrustScoreResult(
      score: total.clamp(0, 100),
      note: _noteFor(total.clamp(0, 100)),
    );
  }

  static String _noteFor(double score) {
    if (score >= 85) return 'Excellent — customers trust you highly.';
    if (score >= 70) return 'Good — keep up consistent, timely service.';
    if (score >= 50)
      return 'Fair — faster responses and fewer cancellations will help.';
    return 'Needs improvement — focus on completing jobs reliably.';
  }
}
