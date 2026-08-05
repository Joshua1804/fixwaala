import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/services/firebase_service.dart';

class AdminDirectoryEntry {
  final String uid;
  final String email;
  final String? displayName;
  final DateTime? grantedAt;
  final String? grantedBy;

  const AdminDirectoryEntry({
    required this.uid,
    required this.email,
    this.displayName,
    this.grantedAt,
    this.grantedBy,
  });

  factory AdminDirectoryEntry.fromMap(String uid, Map<String, dynamic> map) {
    final grantedAt = map['grantedAt'];
    return AdminDirectoryEntry(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String?,
      grantedAt: grantedAt is fs.Timestamp ? grantedAt.toDate() : null,
      grantedBy: map['grantedBy'] as String?,
    );
  }
}

/// Read-only view of `admins/{uid}` — see the collection's rules comment.
/// Nothing here can write it; that's `scripts/admin/grant_admin_claim.js`.
class AdminDirectoryService {
  AdminDirectoryService._();
  static final AdminDirectoryService instance = AdminDirectoryService._();

  Stream<List<AdminDirectoryEntry>> watch() {
    return FirebaseService.instance.firestore
        .collection('admins')
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((d) => AdminDirectoryEntry.fromMap(d.id, d.data()))
                  .toList()
                ..sort((a, b) => a.email.compareTo(b.email)),
        );
  }
}
