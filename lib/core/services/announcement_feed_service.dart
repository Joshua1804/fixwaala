import '../models/announcement.dart';
import '../models/enums.dart';
import 'firebase_service.dart';

/// [all] filtered down to what [viewerRole] should see right now: active,
/// not expired, and targeted at their role (or everyone). Newest first.
///
/// Pure so it's unit-testable without Firestore, and reused by both
/// [AnnouncementFeedService.watchFor] and the notifications screen if it
/// ever needs to re-filter a cached list.
List<Announcement> visibleAnnouncements(
  List<Announcement> all, {
  required UserRole viewerRole,
  required DateTime now,
}) {
  final visible = all.where((a) {
    if (!a.active) return false;
    if (a.expiresAt != null && a.expiresAt!.isBefore(now)) return false;
    if (a.audience == AnnouncementAudience.all) return true;
    return (a.audience == AnnouncementAudience.customer &&
            viewerRole == UserRole.customer) ||
        (a.audience == AnnouncementAudience.provider &&
            viewerRole == UserRole.provider);
  }).toList();
  visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return visible;
}

/// Read-only access to admin announcements for the customer/provider apps.
class AnnouncementFeedService {
  AnnouncementFeedService._();
  static final AnnouncementFeedService instance = AnnouncementFeedService._();

  bool get _live => FirebaseService.instance.isInitialized;

  /// Announcements visible to [role], live-updating as the admin
  /// website publishes/unpublishes them. Empty when not running against a
  /// real Firebase project (there is no simulated announcement fixture data).
  Stream<List<Announcement>> watchFor(UserRole role) {
    if (!_live) return Stream.value(const []);
    return FirebaseService.instance.firestore
        .collection('announcements')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .map(
          (snap) => visibleAnnouncements(
            snap.docs.map((d) => Announcement.fromMap(d.data())).toList(),
            viewerRole: role,
            now: DateTime.now(),
          ),
        );
  }
}
