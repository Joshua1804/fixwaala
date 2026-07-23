import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/features/provider_dashboard/services/trust_score_calculator.dart';

void main() {
  group('Trust score calculation', () {
    test('returns no score when the provider has no completed jobs', () {
      final result = TrustScoreCalculator.calculate(
        completedJobs: 0,
        ratingAverage: 0,
        completionRate: 0,
        cancellationRate: 0,
        avgResponseSeconds: 0,
      );
      expect(result.hasScore, isFalse);
      expect(result.score, isNull);
    });

    test('a perfect record scores at (or very near) 100', () {
      final result = TrustScoreCalculator.calculate(
        completedJobs: 10,
        ratingAverage: 5,
        completionRate: 1,
        cancellationRate: 0,
        avgResponseSeconds: 0,
      );
      expect(result.hasScore, isTrue);
      expect(result.score!, closeTo(100, 0.01));
    });

    test('matches the documented weighted-sum formula for mixed inputs', () {
      // weights: rating .40, completion .30, response .15, cancellation .15
      // rating 4/5 -> 0.8 * 0.40 = 0.32
      // completion 0.8 -> 0.8 * 0.30 = 0.24
      // response 150s of 300s max -> (1 - 0.5) * 0.15 = 0.075
      // cancellation 0.2 -> (1 - 0.2) * 0.15 = 0.12
      // total = 0.755 -> 75.5
      final result = TrustScoreCalculator.calculate(
        completedJobs: 5,
        ratingAverage: 4,
        completionRate: 0.8,
        cancellationRate: 0.2,
        avgResponseSeconds: 150,
      );
      expect(result.hasScore, isTrue);
      expect(result.score!, closeTo(75.5, 0.01));
    });

    test('a very slow response time is clamped rather than going negative', () {
      final result = TrustScoreCalculator.calculate(
        completedJobs: 3,
        ratingAverage: 5,
        completionRate: 1,
        cancellationRate: 0,
        avgResponseSeconds: 10000, // far beyond the max acceptable window
      );
      expect(result.hasScore, isTrue);
      // response component contributes 0, so score = 40 + 30 + 0 + 15 = 85
      expect(result.score!, closeTo(85, 0.01));
    });

    test('score is always clamped within 0..100', () {
      final result = TrustScoreCalculator.calculate(
        completedJobs: 1,
        ratingAverage: 0,
        completionRate: 0,
        cancellationRate: 1,
        avgResponseSeconds: 10000,
      );
      expect(result.score! >= 0 && result.score! <= 100, isTrue);
    });
  });
}
