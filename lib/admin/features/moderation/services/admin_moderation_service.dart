import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/models/enums.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../features/ratings/models/rating_model.dart';
import '../../../../features/reports_safety/models/report_model.dart';
import '../../../core/admin_audit_service.dart';

class ReportPage {
  final List<Report> reports;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const ReportPage({
    required this.reports,
    required this.lastDoc,
    required this.hasMore,
  });
}

class RatingPage {
  final List<Rating> ratings;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const RatingPage({
    required this.ratings,
    required this.lastDoc,
    required this.hasMore,
  });
}

/// Trust & safety moderation: reports, safety alerts, and rating takedowns.
/// All three are admin-write-only in `firestore.rules` — the app can only
/// create a report/alert or leave a rating; resolving, annotating, or
/// deleting is exclusively this screen's job.
class AdminModerationService {
  AdminModerationService._();
  static final AdminModerationService instance = AdminModerationService._();

  fs.CollectionReference<Map<String, dynamic>> get _reportsCol =>
      FirebaseService.instance.firestore.collection('reports');
  fs.CollectionReference<Map<String, dynamic>> get _safetyAlertsCol =>
      FirebaseService.instance.firestore.collection('safetyAlerts');
  fs.CollectionReference<Map<String, dynamic>> get _ratingsCol =>
      FirebaseService.instance.firestore.collection('ratings');

  // ── Reports ──────────────────────────────────────────────────────

  Future<ReportPage> fetchReportPage({
    ReportStatus? status,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _reportsCol;
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return ReportPage(
      reports: pageDocs.map((d) => Report.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<Report?> fetchReport(String id) async {
    final doc = await _reportsCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Report.fromMap(doc.data()!);
  }

  Future<void> resolveReport(
    Report report, {
    required ReportStatus status,
    required String adminNote,
    required String adminId,
  }) async {
    await _reportsCol.doc(report.id).update({
      'status': status.name,
      'adminNote': adminNote,
      'resolvedByAdminId': adminId,
      'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
    });
    await AdminAuditService.instance.log(
      action: 'report.resolve',
      targetType: 'report',
      targetId: report.id,
      details: {'status': status.name, 'note': adminNote},
    );
  }

  // ── Safety alerts ────────────────────────────────────────────────

  /// Live — an unresolved safety alert is urgent enough that a paginated
  /// pull-to-refresh model is the wrong fit.
  Stream<List<SafetyAlert>> watchSafetyAlerts({bool? resolved}) {
    fs.Query<Map<String, dynamic>> query = _safetyAlertsCol;
    if (resolved != null) {
      query = query
          .where('resolved', isEqualTo: resolved)
          .orderBy('raisedAt', descending: true);
    } else {
      query = query.orderBy('raisedAt', descending: true);
    }
    return query
        .limit(200)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => SafetyAlert.fromMap(d.data())).toList(),
        );
  }

  Future<void> resolveSafetyAlert(
    SafetyAlert alert, {
    required String adminId,
  }) async {
    await _safetyAlertsCol.doc(alert.id).update({
      'resolved': true,
      'resolvedByAdminId': adminId,
      'resolvedAt': fs.Timestamp.fromDate(DateTime.now()),
    });
    await AdminAuditService.instance.log(
      action: 'safety_alert.resolve',
      targetType: 'safetyAlert',
      targetId: alert.id,
      details: {},
    );
  }

  // ── Ratings ──────────────────────────────────────────────────────

  Future<RatingPage> fetchRatingPage({
    int? maxStars,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _ratingsCol;
    if (maxStars != null) {
      // `stars <= maxStars` combined with `orderBy(createdAt)` would need a
      // composite index this app doesn't declare, and reviews worth
      // moderating are a small slice of all ratings — order by stars
      // instead, which needs none beyond the automatic single-field index.
      query = query
          .where('stars', isLessThanOrEqualTo: maxStars)
          .orderBy('stars')
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return RatingPage(
      ratings: pageDocs.map((d) => Rating.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<void> deleteRating(Rating rating) async {
    await _ratingsCol.doc(rating.id).delete();
    await AdminAuditService.instance.log(
      action: 'rating.delete',
      targetType: 'rating',
      targetId: rating.id,
      details: {'jobId': rating.jobId, 'stars': rating.stars},
    );
  }
}
