import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/models/enums.dart';

/// A single provider's candidacy on a ticket, persisted at
/// `tickets/{ticketId}/candidates/{providerId}`. Created when a provider
/// accepts an opportunity; the customer reviews the live list of these and
/// confirms one, which flips the others to [CandidateStatus.notSelected].
class CandidateLease {
  final String ticketId;
  final String providerId;
  final String displayName;
  final ServiceCategory category;
  final double distanceKm;
  final int etaMinutes;
  final double ratingAverage;
  final int completedJobs;
  final bool verified;

  /// The provider's own contact number, written by the provider when they
  /// accept. `users/{uid}` is owner-only readable, so this is how the number
  /// reaches the customer at confirmation without opening up user documents.
  final String? phone;

  final CandidateStatus status;
  final DateTime leasedAt;
  final DateTime expiresAt;

  const CandidateLease({
    required this.ticketId,
    required this.providerId,
    required this.displayName,
    required this.category,
    required this.distanceKm,
    required this.etaMinutes,
    required this.ratingAverage,
    required this.completedJobs,
    required this.verified,
    this.phone,
    required this.leasedAt,
    required this.expiresAt,
    this.status = CandidateStatus.pending,
  });

  Duration get remaining {
    final now = DateTime.now();
    if (now.isAfter(expiresAt)) return Duration.zero;
    return expiresAt.difference(now);
  }

  CandidateLease copyWith({CandidateStatus? status}) {
    return CandidateLease(
      ticketId: ticketId,
      providerId: providerId,
      displayName: displayName,
      category: category,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      ratingAverage: ratingAverage,
      completedJobs: completedJobs,
      verified: verified,
      phone: phone,
      leasedAt: leasedAt,
      expiresAt: expiresAt,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toMap() => {
    'ticketId': ticketId,
    'providerId': providerId,
    'displayName': displayName,
    'category': category.name,
    'distanceKm': distanceKm,
    'etaMinutes': etaMinutes,
    'ratingAverage': ratingAverage,
    'completedJobs': completedJobs,
    'verified': verified,
    if (phone != null) 'phone': phone,
    'status': status.name,
    'leasedAt': fs.Timestamp.fromDate(leasedAt),
    'expiresAt': fs.Timestamp.fromDate(expiresAt),
  };

  factory CandidateLease.fromMap(Map<String, dynamic> map) {
    final leasedAt = map['leasedAt'];
    final expiresAt = map['expiresAt'];
    return CandidateLease(
      ticketId: map['ticketId'] as String? ?? '',
      providerId: map['providerId'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      category: ServiceCategory.values.byNameOrDefault(
        map['category'] as String?,
        ServiceCategory.unknown,
      ),
      distanceKm: (map['distanceKm'] as num?)?.toDouble() ?? 0,
      etaMinutes: (map['etaMinutes'] as num?)?.toInt() ?? 0,
      ratingAverage: (map['ratingAverage'] as num?)?.toDouble() ?? 0,
      completedJobs: (map['completedJobs'] as num?)?.toInt() ?? 0,
      verified: map['verified'] as bool? ?? false,
      phone: map['phone'] as String?,
      status: CandidateStatus.values.byNameOrDefault(
        map['status'] as String?,
        CandidateStatus.pending,
      ),
      leasedAt: leasedAt is fs.Timestamp ? leasedAt.toDate() : DateTime.now(),
      expiresAt: expiresAt is fs.Timestamp
          ? expiresAt.toDate()
          : DateTime.now(),
    );
  }
}
