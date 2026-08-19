import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/models/enums.dart';

enum AnnouncementPriority { info, warning, critical }

enum AnnouncementAudience { all, customer, provider }

/// An admin-authored banner, stored at `announcements/{id}`.
///
/// This is the closest thing the current architecture has to "notification
/// management" without a server: there is no Cloud Function to fan a message
/// out as push (see docs/RELEASE.md — that needs Blaze), so an announcement
/// is a document any signed-in user can read and the app can show as an
/// in-app banner. The mobile app does not render these yet; see
/// docs/ADMIN_WEB.md for the follow-up.
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

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'body': body,
    'active': active,
    'priority': priority.name,
    'audience': audience.name,
    'createdAt': fs.Timestamp.fromDate(createdAt),
    if (updatedAt != null) 'updatedAt': fs.Timestamp.fromDate(updatedAt!),
    if (expiresAt != null) 'expiresAt': fs.Timestamp.fromDate(expiresAt!),
    'createdByAdminId': createdByAdminId,
  };

  factory Announcement.fromMap(Map<String, dynamic> map) => Announcement(
    id: map['id'] as String? ?? '',
    title: map['title'] as String? ?? '',
    body: map['body'] as String? ?? '',
    active: map['active'] as bool? ?? false,
    priority: AnnouncementPriority.values.byNameOrDefault(
      map['priority'] as String?,
      AnnouncementPriority.info,
    ),
    audience: AnnouncementAudience.values.byNameOrDefault(
      map['audience'] as String?,
      AnnouncementAudience.all,
    ),
    createdAt: _dateFrom(map['createdAt']),
    updatedAt: map['updatedAt'] == null ? null : _dateFrom(map['updatedAt']),
    expiresAt: map['expiresAt'] == null ? null : _dateFrom(map['expiresAt']),
    createdByAdminId: map['createdByAdminId'] as String? ?? '',
  );

  Announcement copyWith({
    String? title,
    String? body,
    bool? active,
    AnnouncementPriority? priority,
    AnnouncementAudience? audience,
    DateTime? updatedAt,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
  }) {
    return Announcement(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      active: active ?? this.active,
      priority: priority ?? this.priority,
      audience: audience ?? this.audience,
      createdAt: createdAt,
      createdByAdminId: createdByAdminId,
      updatedAt: updatedAt ?? this.updatedAt,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
    );
  }
}

DateTime _dateFrom(Object? value) {
  if (value is fs.Timestamp) return value.toDate();
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
