import 'package:cloud_firestore/cloud_firestore.dart' as fs;

enum AnnouncementPriority { info, warning, critical }

enum AnnouncementAudience { all, customer, provider }

/// Read-only client mirror of the admin-authored banner stored at
/// `announcements/{id}`. The admin website (`lib/admin/features/content/`)
/// owns writes; this app only ever reads.
class Announcement {
  final String id;
  final String title;
  final String body;
  final bool active;
  final AnnouncementPriority priority;
  final AnnouncementAudience audience;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? expiresAt;
  final String createdByAdminId;

  const Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.active,
    required this.priority,
    required this.audience,
    required this.createdAt,
    required this.createdByAdminId,
    this.updatedAt,
    this.expiresAt,
  });

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    active: map['active'] as bool? ?? false,
    priority: AnnouncementPriority.values.byName(
      map['priority'] as String? ?? 'info',
    ),
    audience: AnnouncementAudience.values.byName(
      map['audience'] as String? ?? 'all',
    ),
    createdAt: _dateFrom(map['createdAt']),
    updatedAt: map['updatedAt'] == null ? null : _dateFrom(map['updatedAt']),
    expiresAt: map['expiresAt'] == null ? null : _dateFrom(map['expiresAt']),
    createdByAdminId: map['createdByAdminId'] as String? ?? '',
  );
}

DateTime _dateFrom(Object? value) {
  if (value is fs.Timestamp) return value.toDate();
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
