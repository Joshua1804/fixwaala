import '../../../core/models/enums.dart';

/// A user account as seen by the Admin Panel's Account Management screen —
/// combines identity fields with the moderation status an admin controls.
class ManagedAccount {
  final String userId;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final AccountStatus status;
  final String? restrictionReason;
  final DateTime? restrictedUntil;

  const ManagedAccount({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    required this.status,
    this.phone,
    this.restrictionReason,
    this.restrictedUntil,
  });

  ManagedAccount copyWith({
    AccountStatus? status,
    String? restrictionReason,
    DateTime? restrictedUntil,
  }) {
    return ManagedAccount(
      userId: userId,
      name: name,
      email: email,
      phone: phone,
      role: role,
      status: status ?? this.status,
      restrictionReason: restrictionReason ?? this.restrictionReason,
      restrictedUntil: restrictedUntil ?? this.restrictedUntil,
    );
  }
}
