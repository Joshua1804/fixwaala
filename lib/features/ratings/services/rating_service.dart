import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseException;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/services/firebase_service.dart';
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
/// the Provider Dashboard and Trust Score rely on. Ratings are cached
/// in-memory for synchronous aggregate lookups and mirrored to the
/// `ratings` Firestore collection when configured, so reputation survives
/// a reload.
class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  final List<Rating> _ratings = [];
  StreamSubscription? _liveSub;

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('ratings');

  /// Opens the live Firestore sync. Call once at app startup. No-op in
  /// simulation mode.
  Future<void> initialize() async {
    if (!_live) return;
    await _liveSub?.cancel();
    _liveSub = _col.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final rating = Rating.fromMap(change.doc.data()!);
        _ratings.removeWhere((r) => r.id == rating.id);
        _ratings.add(rating);
      }
    });
  }

  Future<void> _persist(Rating rating) async {
    if (!_live) return;
    try {
      await _col.doc(rating.id).set(rating.toMap());
    } on FirebaseException catch (e) {
      if (kDebugMode && e.code == 'permission-denied') {
        debugPrint(
          '[RatingService] Firestore denied rating write; continuing in '
          'local cache only. Update Firestore rules before release.',
        );
        return;
      }
      rethrow;
    }
  }

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
    unawaited(_persist(rating));

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
