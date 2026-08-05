import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_facing_exception.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/session_scoped_sync.dart';
import '../../../core/services/account_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/rating_model.dart';

class DuplicateRatingException implements UserFacingException {
  @override
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
  late final SessionScopedSync _sync = SessionScopedSync(
    debugName: 'RatingService',
    // Ratings this user wrote (for the duplicate guard) and ratings they
    // received (for their own aggregates). Another user's reputation is read
    // on demand via [fetchRatingsFor], not held in this cache.
    queriesForUser: (uid) => [
      _col.where('fromUserId', isEqualTo: uid),
      _col.where('toUserId', isEqualTo: uid),
    ],
    onChange: (change) {
      final rating = Rating.fromMap(change.doc.data()!);
      instance._ratings.removeWhere((r) => r.id == rating.id);
      instance._ratings.add(rating);
    },
    onClear: () => instance._ratings.clear(),
  );

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('ratings');

  /// Binds the live Firestore sync to the signed-in user. Call once at app
  /// startup; it waits for auth itself. No-op in simulation mode.
  Future<void> initialize() => _sync.start();

  /// Ends the session sync and drops every cached rating.
  Future<void> endSession() => _sync.stop();

  /// Public reputation for [userId], fetched on demand.
  ///
  /// A customer viewing a candidate's profile is not a party to that
  /// provider's ratings, so they are not in the session cache. Reputation is
  /// deliberately world-readable — that is what makes it a reputation — but
  /// it is read as a bounded query rather than by holding every rating on the
  /// platform in memory.
  Future<List<Rating>> fetchRatingsFor(String userId) async {
    if (!_live) return ratingsFor(userId);
    final snap = await _col.where('toUserId', isEqualTo: userId).get();
    return snap.docs.map((d) => Rating.fromMap(d.data())).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<void> _persist(Rating rating) async {
    if (!_live) return;
    await _col.doc(rating.id).set(rating.toMap());
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
      // Deterministic id, matched by `firestore.rules`. The in-app duplicate
      // check above runs against a local cache and so cannot be trusted on
      // its own; deriving the document id from (job, rater) makes a second
      // rating for the same job a server-side write conflict rather than a
      // race the client happens to win.
      id: '${jobId}_$fromUserId',
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
