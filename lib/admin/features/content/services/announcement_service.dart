import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/services/firebase_service.dart';
import '../../../core/admin_audit_service.dart';
import '../models/announcement.dart';

class AnnouncementService {
  AnnouncementService._();
  static final AnnouncementService instance = AnnouncementService._();

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('announcements');

  Stream<List<Announcement>> watchAll() {
    return _col
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => Announcement.fromMap(d.data())).toList(),
        );
  }

  Future<void> create({
    required String title,
    required String body,
    required AnnouncementPriority priority,
    required AnnouncementAudience audience,
    required String adminId,
    DateTime? expiresAt,
  }) async {
    final docRef = _col.doc();
    final announcement = Announcement(
      id: docRef.id,
      title: title,
      body: body,
      active: true,
      priority: priority,
      audience: audience,
      createdAt: DateTime.now(),
      createdByAdminId: adminId,
      expiresAt: expiresAt,
    );
    await docRef.set(announcement.toMap());
    await AdminAuditService.instance.log(
      action: 'announcement.create',
      targetType: 'announcement',
      targetId: docRef.id,
      details: {'title': title, 'priority': priority.name},
    );
  }

  Future<void> update(Announcement announcement) async {
    final updated = announcement.copyWith(updatedAt: DateTime.now());
    await _col.doc(announcement.id).set(updated.toMap());
    await AdminAuditService.instance.log(
      action: 'announcement.update',
      targetType: 'announcement',
      targetId: announcement.id,
      details: {'title': updated.title, 'active': updated.active},
    );
  }

  Future<void> setActive(Announcement announcement, bool active) async {
    await update(announcement.copyWith(active: active));
  }

  Future<void> delete(Announcement announcement) async {
    await _col.doc(announcement.id).delete();
    await AdminAuditService.instance.log(
      action: 'announcement.delete',
      targetType: 'announcement',
      targetId: announcement.id,
      details: {'title': announcement.title},
    );
  }
}
