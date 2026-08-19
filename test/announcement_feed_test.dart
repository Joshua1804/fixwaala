import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/announcement.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/services/announcement_feed_service.dart';

Announcement _announcement({
  required String id,
  AnnouncementAudience audience = AnnouncementAudience.all,
  bool active = true,
  DateTime? expiresAt,
  DateTime? createdAt,
}) {
  return Announcement(
    id: id,
    title: 'Title $id',
    body: 'Body $id',
    active: active,
    priority: AnnouncementPriority.info,
    audience: audience,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    createdByAdminId: 'admin_1',
    expiresAt: expiresAt,
  );
}

void main() {
  final now = DateTime(2026, 6, 1);

  test('excludes inactive announcements', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', active: false)],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('excludes expired announcements', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', expiresAt: DateTime(2026, 1, 1))],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('includes "all" audience for both roles', () {
    final announcement = _announcement(id: '1');
    for (final role in [UserRole.customer, UserRole.provider]) {
      final result = visibleAnnouncements(
        [announcement],
        viewerRole: role,
        now: now,
      );
      expect(result, [announcement]);
    }
  });

  test('excludes provider-only announcements for a customer viewer', () {
    final result = visibleAnnouncements(
      [_announcement(id: '1', audience: AnnouncementAudience.provider)],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, isEmpty);
  });

  test('sorts newest first', () {
    final older = _announcement(id: 'old', createdAt: DateTime(2026, 1, 1));
    final newer = _announcement(id: 'new', createdAt: DateTime(2026, 5, 1));
    final result = visibleAnnouncements(
      [older, newer],
      viewerRole: UserRole.customer,
      now: now,
    );
    expect(result, [newer, older]);
  });
}
