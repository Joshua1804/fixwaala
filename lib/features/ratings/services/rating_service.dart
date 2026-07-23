import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../admin_panel/services/account_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/rating_model.dart';

class DuplicateRatingException implements Exception {
  final String message;
  DuplicateRatingException(this.message);

  @override
  String toString() => message;
}

/// Ratings & Reputation (Module 9).
///
/// Enforces one rating per (job, rater) pair and exposes the aggregates
/// the Provider Dashboard and Trust Score rely on.
class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  final List<Rating> _ratings = [];

  @visibleForTesting
  void resetForTesting() => _ratings.clear();

  bool hasRated({required String jobId, required String fromUserId}) =>
      _ratings.any((r) => r.jobId == jobId && r.fromUserId == fromUserId);

  Future<Rating> submit({
    required String jobId,
    required String fromUserId,
    required String toUserId,
    required RatingDirection direction,
    required int stars,
    String? review,
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError('Rating must be between 1 and 5 stars.');
    }
    AccountService.instance.assertActive(fromUserId);
    final job = JobService.instance.jobById(jobId);
    if (job == null) {
      throw ArgumentError('This job no longer exists.');
    }
    if (!job.paid) {
      throw StateError('You can only rate a job once it has been paid for.');
    }
    if (hasRated(jobId: jobId, fromUserId: fromUserId)) {
      throw DuplicateRatingException('You have already rated this job.');
    }
    final rating = Rating(
      id: 'rating-${DateTime.now().microsecondsSinceEpoch}',
      jobId: jobId,
      fromUserId: fromUserId,
      toUserId: toUserId,
      direction: direction,
      stars: stars,
      review: (review == null || review.trim().isEmpty) ? null : review.trim(),
      createdAt: DateTime.now(),
    );
    _ratings.add(rating);

    await JobService.instance.markRated(jobId, direction: direction);
    return rating;
  }

  List<Rating> ratingsFor(String userId) =>
      _ratings.where((r) => r.toUserId == userId).toList();

  double averageForUser(String userId) {
    final mine = ratingsFor(userId);
    if (mine.isEmpty) return 0;
    return mine.map((r) => r.stars).reduce((a, b) => a + b) / mine.length;
  }

  int ratingCountForUser(String userId) => ratingsFor(userId).length;
}
