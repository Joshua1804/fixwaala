import 'package:cloud_firestore/cloud_firestore.dart' as fs;

/// The single tunables document at `platformSettings/config`.
///
/// **The Android app does not read this yet** — it still compiles
/// `AppConstants` in at build time. This document exists so an admin has
/// somewhere real to change these values without a redeploy in the future;
/// wiring the app to read it live is a follow-up integration, not part of
/// this admin module. See docs/ADMIN_WEB.md.
class PlatformSettings {
  final bool maintenanceMode;
  final String maintenanceMessage;
  final String supportEmail;
  final String supportPhone;
  final List<double> searchRadiiKm;
  final int candidateReviewSeconds;
  final String minSupportedAppVersion;
  final DateTime? updatedAt;
  final String? updatedByAdminId;

  const PlatformSettings({
    this.maintenanceMode = false,
    this.maintenanceMessage = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.searchRadiiKm = const [5, 10, 15],
    this.candidateReviewSeconds = 180,
    this.minSupportedAppVersion = '1.0.0',
    this.updatedAt,
    this.updatedByAdminId,
  });

  Map<String, dynamic> toMap() => {
    'maintenanceMode': maintenanceMode,
    'maintenanceMessage': maintenanceMessage,
    'supportEmail': supportEmail,
    'supportPhone': supportPhone,
    'searchRadiiKm': searchRadiiKm,
    'candidateReviewSeconds': candidateReviewSeconds,
    'minSupportedAppVersion': minSupportedAppVersion,
    'updatedAt': fs.FieldValue.serverTimestamp(),
    if (updatedByAdminId != null) 'updatedByAdminId': updatedByAdminId,
  };

  factory PlatformSettings.fromMap(Map<String, dynamic> map) {
    final updatedAt = map['updatedAt'];
    return PlatformSettings(
      maintenanceMode: map['maintenanceMode'] as bool? ?? false,
      maintenanceMessage: map['maintenanceMessage'] as String? ?? '',
      supportEmail: map['supportEmail'] as String? ?? '',
      supportPhone: map['supportPhone'] as String? ?? '',
      searchRadiiKm: (map['searchRadiiKm'] as List<dynamic>? ?? const [5, 10, 15])
          .map((v) => (v as num).toDouble())
          .toList(),
      candidateReviewSeconds: (map['candidateReviewSeconds'] as num?)?.toInt() ?? 180,
      minSupportedAppVersion: map['minSupportedAppVersion'] as String? ?? '1.0.0',
      updatedAt: updatedAt is fs.Timestamp ? updatedAt.toDate() : null,
      updatedByAdminId: map['updatedByAdminId'] as String?,
    );
  }

  PlatformSettings copyWith({
    bool? maintenanceMode,
    String? maintenanceMessage,
    String? supportEmail,
    String? supportPhone,
    List<double>? searchRadiiKm,
    int? candidateReviewSeconds,
    String? minSupportedAppVersion,
    String? updatedByAdminId,
  }) {
    return PlatformSettings(
      maintenanceMode: maintenanceMode ?? this.maintenanceMode,
      maintenanceMessage: maintenanceMessage ?? this.maintenanceMessage,
      supportEmail: supportEmail ?? this.supportEmail,
      supportPhone: supportPhone ?? this.supportPhone,
      searchRadiiKm: searchRadiiKm ?? this.searchRadiiKm,
      candidateReviewSeconds: candidateReviewSeconds ?? this.candidateReviewSeconds,
      minSupportedAppVersion: minSupportedAppVersion ?? this.minSupportedAppVersion,
      updatedByAdminId: updatedByAdminId ?? this.updatedByAdminId,
    );
  }
}
