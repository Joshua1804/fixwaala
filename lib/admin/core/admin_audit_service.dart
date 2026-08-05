import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../core/services/firebase_service.dart';
import 'admin_auth_service.dart';

/// A single entry in `auditEvents` — an immutable record of one privileged
/// action taken through the admin website. Rules make the collection
/// admin-create, nobody-update-or-delete, so this is a genuine trail, not a
/// log that could be quietly edited by the person it's watching.
class AuditEvent {
  final String id;
  final String actorAdminId;
  final String actorAdminEmail;
  final String action;
  final String targetType;
  final String targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.actorAdminId,
    required this.actorAdminEmail,
    required this.action,
    required this.targetType,
    required this.targetId,
    required this.details,
    required this.createdAt,
  });

  factory AuditEvent.fromMap(Map<String, dynamic> map) => AuditEvent(
    id: map['id'] as String? ?? '',
    actorAdminId: map['actorAdminId'] as String? ?? '',
    actorAdminEmail: map['actorAdminEmail'] as String? ?? '',
    action: map['action'] as String? ?? '',
    targetType: map['targetType'] as String? ?? '',
    targetId: map['targetId'] as String? ?? '',
    details: Map<String, dynamic>.from(map['details'] as Map? ?? const {}),
    createdAt: map['createdAt'] is fs.Timestamp
        ? (map['createdAt'] as fs.Timestamp).toDate()
        : DateTime.now(),
  );
}

/// Writes to `auditEvents`. Every screen that mutates platform data (users,
/// tickets, jobs, payments, reports, content, settings) calls [log] right
/// after the write succeeds — see each feature's service for the call sites.
class AdminAuditService {
  AdminAuditService._();
  static final AdminAuditService instance = AdminAuditService._();

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('auditEvents');

  Future<void> log({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic> details = const {},
  }) async {
    final docRef = _col.doc();
    await docRef.set({
      'id': docRef.id,
      'actorAdminId': AdminAuthService.instance.currentUid ?? 'unknown',
      'actorAdminEmail': AdminAuthService.instance.currentEmail ?? 'unknown',
      'action': action,
      'targetType': targetType,
      'targetId': targetId,
      'details': details,
      'createdAt': fs.FieldValue.serverTimestamp(),
    });
  }

  /// Recent events, newest first, optionally filtered.
  Stream<List<AuditEvent>> watch({
    String? actorAdminId,
    String? targetType,
    int limit = 100,
  }) {
    fs.Query<Map<String, dynamic>> query = _col;
    if (actorAdminId != null) {
      query = query
          .where('actorAdminId', isEqualTo: actorAdminId)
          .orderBy('createdAt', descending: true);
    } else if (targetType != null) {
      query = query
          .where('targetType', isEqualTo: targetType)
          .orderBy('createdAt', descending: true);
    } else {
      query = query.orderBy('createdAt', descending: true);
    }
    return query
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map((d) => AuditEvent.fromMap(d.data())).toList(),
        );
  }
}
