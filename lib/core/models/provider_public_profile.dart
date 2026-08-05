import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import 'enums.dart';

/// The subset of a provider's account that any signed-in customer may read,
/// stored at `providerPublicProfiles/{uid}`.
///
/// `users/{uid}` is owner-only readable — it carries phone, address, pincode,
/// and live GPS, and reading it wholesale is what previously exposed every
/// account's home address to anyone signed in. A customer choosing between
/// candidates still needs to see who they are considering, so the safe fields
/// are mirrored here.
///
/// **Nothing in the app writes this document.** It is maintained by the
/// `mirrorProviderPublicProfile` Cloud Function, which is the only writer the
/// rules permit. That matters for [isVerified] in particular: the badge is an
/// administrator's decision, and a client that could write its own mirror
/// could award itself the badge.
class ProviderPublicProfile {
  final String id;
  final String name;

  /// Set by an administrator after manual review. Never self-assigned.
  final bool isVerified;

  final DateTime createdAt;
  final List<ServiceCategory> skills;
  final int? experienceYears;
  final String? serviceArea;

  const ProviderPublicProfile({
    required this.id,
    required this.name,
    required this.isVerified,
    required this.createdAt,
    this.skills = const [],
    this.experienceYears,
    this.serviceArea,
  });

  factory ProviderPublicProfile.fromMap(Map<String, dynamic> map) {
    return ProviderPublicProfile(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? 'Provider',
      isVerified: map['isVerified'] as bool? ?? false,
      // `AppUser` stores this as an ISO-8601 string, and the projection is a
      // straight copy; `Timestamp` is accepted too in case the admin website
      // ever writes one.
      createdAt: _dateFrom(map['createdAt']),
      skills: (map['skills'] as List<dynamic>? ?? [])
          .map((s) => ServiceCategory.values.byName(s as String))
          .toList(),
      experienceYears: map['experienceYears'] as int?,
      serviceArea: map['serviceArea'] as String?,
    );
  }

  static DateTime _dateFrom(Object? value) {
    if (value is fs.Timestamp) return value.toDate();
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
