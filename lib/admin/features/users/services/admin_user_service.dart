import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/models/enums.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../core/admin_audit_service.dart';

class UserPage {
  final List<AppUser> users;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const UserPage({required this.users, required this.lastDoc, required this.hasMore});
}

/// Admin's view of the `users` collection: browse/filter/paginate, search,
/// and moderate. All reads here are only possible because `firestore.rules`
/// grants `isAdmin()` an unrestricted read on `users/{userId}` — nothing
/// special happens in this service to earn that, it's just what the
/// signed-in account's ID token already carries.
class AdminUserService {
  AdminUserService._();
  static final AdminUserService instance = AdminUserService._();

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('users');
  fs.CollectionReference<Map<String, dynamic>> get _publicProfilesCol =>
      FirebaseService.instance.firestore.collection('providerPublicProfiles');

  /// Browse, filtered by role and/or account status, newest first.
  Future<UserPage> fetchPage({
    required UserRole? role,
    AccountStatus? status,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _col;
    if (role != null) {
      query = query.where('role', isEqualTo: role.name);
      if (status != null) {
        query = query.where('accountStatus', isEqualTo: status.name);
      }
      query = query.orderBy('createdAt', descending: true);
    } else {
      // No role filter: `createdAt` alone needs no composite index. A status
      // filter with no role filter would (`accountStatus` + `createdAt`
      // without `role` isn't one of the indexes declared), so status is only
      // honored when a role is also chosen — the UI disables it otherwise.
      query = query.orderBy('createdAt', descending: true);
    }
    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return UserPage(
      users: pageDocs.map((d) => AppUser.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  /// Exact-email or name-prefix search. Firestore has no full-text search
  /// without a third-party index (Algolia/Typesense) — this is the honest
  /// boundary of what a single-field range/equality query can do. A prefix
  /// search on `name` is done with the standard Firestore range trick: end
  /// the range at the search term with a high sentinel codepoint appended,
  /// so it sorts after every string that starts with the term.
  Future<List<AppUser>> search(String term) async {
    final trimmed = term.trim();
    if (trimmed.isEmpty) return [];
    if (trimmed.contains('@')) {
      final snap = await _col
          .where('email', isEqualTo: trimmed.toLowerCase())
          .limit(20)
          .get();
      return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
    }
    final rangeEnd = '$trimmed';
    final snap = await _col
        .orderBy('name')
        .startAt([trimmed])
        .endAt([rangeEnd])
        .limit(20)
        .get();
    return snap.docs.map((d) => AppUser.fromMap(d.data())).toList();
  }

  Future<AppUser?> fetchOne(String userId) async {
    final doc = await _col.doc(userId).get();
    if (!doc.exists || doc.data() == null) return null;
    return AppUser.fromMap(doc.data()!);
  }

  /// Editable-by-admin fields only — a deliberately smaller set than what
  /// `firestore.rules` would technically allow `isAdmin()` to write, so a
  /// slip in this screen can't silently rewrite `role` or `createdAt`.
  Future<void> updateProfile(AppUser user, {String? name, String? phone}) async {
    await _col.doc(user.id).update({
      'name': ?name,
      'phone': ?phone,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await AdminAuditService.instance.log(
      action: 'user.update_profile',
      targetType: 'user',
      targetId: user.id,
      details: {'name': ?name, 'phone': ?phone},
    );
  }

  Future<void> setAccountStatus(
    AppUser user,
    AccountStatus status, {
    required String reason,
  }) async {
    await _col.doc(user.id).update({
      'accountStatus': status.name,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await AdminAuditService.instance.log(
      action: 'user.set_account_status',
      targetType: 'user',
      targetId: user.id,
      details: {'status': status.name, 'reason': reason, 'email': user.email},
    );
  }

  /// Grants or revokes the Verified badge. The provider's own device
  /// republishes `providerPublicProfiles/{uid}` to match on its next launch
  /// — see `ProviderDirectoryService.publishSelf` in the mobile app and
  /// `docs/ADMIN_DATA_CONTRACT.md`.
  Future<void> setVerified(AppUser user, bool verified) async {
    await _col.doc(user.id).update({
      'isVerified': verified,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await AdminAuditService.instance.log(
      action: verified ? 'user.verify' : 'user.unverify',
      targetType: 'user',
      targetId: user.id,
      details: {'email': user.email},
    );
  }

  /// Deletes the Firestore profile (and, for a provider, their public
  /// profile mirror). **Does not delete the Firebase Auth account** —
  /// nothing client-side can; that needs the Admin SDK. Run
  /// `node scripts/admin/delete_user.js <email>` afterwards to remove the
  /// login itself — see `scripts/admin/README.md`.
  Future<void> deleteProfile(AppUser user) async {
    await _col.doc(user.id).delete();
    if (user.role == UserRole.provider) {
      await _publicProfilesCol.doc(user.id).delete().catchError((_) {});
    }
    await AdminAuditService.instance.log(
      action: 'user.delete_profile',
      targetType: 'user',
      targetId: user.id,
      details: {'email': user.email, 'role': user.role.name},
    );
  }
}
