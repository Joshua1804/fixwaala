import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/models/enums.dart';

class Report {
  final String id;
  final String reporterId;
  final String? againstUserId;
  final String? ticketId;
  final String? jobId;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final ReportSeverity severity;
  final ReportStatus status;
  final String? adminNote;
  final String? resolvedByAdminId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reason,
    required this.description,
    required this.evidenceUrls,
    required this.severity,
    required this.createdAt,
    this.status = ReportStatus.open,
    this.adminNote,
    this.resolvedByAdminId,
    this.updatedAt,
    this.againstUserId,
    this.ticketId,
    this.jobId,
  });

  /// Firestore shape. Field names are the contract the admin website reads —
  /// see `docs/ADMIN_DATA_CONTRACT.md` before renaming anything here.
  Map<String, dynamic> toMap() => {
    'id': id,
    'reporterId': reporterId,
    if (againstUserId != null) 'againstUserId': againstUserId,
    if (ticketId != null) 'ticketId': ticketId,
    if (jobId != null) 'jobId': jobId,
    'reason': reason,
    'description': description,
    'evidenceUrls': evidenceUrls,
    'severity': severity.name,
    'status': status.name,
    if (adminNote != null) 'adminNote': adminNote,
    if (resolvedByAdminId != null) 'resolvedByAdminId': resolvedByAdminId,
    'createdAt': fs.Timestamp.fromDate(createdAt),
    if (updatedAt != null) 'updatedAt': fs.Timestamp.fromDate(updatedAt!),
  };

  factory Report.fromMap(Map<String, dynamic> map) => Report(
    id: map['id'] as String? ?? '',
    reporterId: map['reporterId'] as String? ?? '',
    againstUserId: map['againstUserId'] as String?,
    ticketId: map['ticketId'] as String?,
    jobId: map['jobId'] as String?,
    reason: map['reason'] as String? ?? '',
    description: map['description'] as String? ?? '',
    evidenceUrls: List<String>.from(map['evidenceUrls'] ?? const []),
    severity: ReportSeverity.values.byNameOrDefault(
      map['severity'] as String?,
      ReportSeverity.medium,
    ),
    status: ReportStatus.values.byNameOrDefault(
      map['status'] as String?,
      ReportStatus.open,
    ),
    adminNote: map['adminNote'] as String?,
    resolvedByAdminId: map['resolvedByAdminId'] as String?,
    createdAt: _dateFrom(map['createdAt']),
    updatedAt: map['updatedAt'] == null ? null : _dateFrom(map['updatedAt']),
  );

  Report copyWith({
    ReportStatus? status,
    String? adminNote,
    String? resolvedByAdminId,
    DateTime? updatedAt,
  }) {
    return Report(
      id: id,
      reporterId: reporterId,
      reason: reason,
      description: description,
      evidenceUrls: evidenceUrls,
      severity: severity,
      createdAt: createdAt,
      status: status ?? this.status,
      adminNote: adminNote ?? this.adminNote,
      resolvedByAdminId: resolvedByAdminId ?? this.resolvedByAdminId,
      updatedAt: updatedAt ?? this.updatedAt,
      againstUserId: againstUserId,
      ticketId: ticketId,
      jobId: jobId,
    );
  }
}

/// An emergency (SOS) alert raised during an active job.
///
/// Every safety alert is treated as high severity by definition — it exists
/// specifically to interrupt an in-progress job and page an admin.
class SafetyAlert {
  final String id;
  final String userId;
  final String? ticketId;
  final String? jobId;
  final bool resolved;
  final String? resolvedByAdminId;
  final DateTime raisedAt;
  final DateTime? resolvedAt;

  const SafetyAlert({
    required this.id,
    required this.userId,
    required this.raisedAt,
    this.ticketId,
    this.jobId,
    this.resolved = false,
    this.resolvedByAdminId,
    this.resolvedAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    if (ticketId != null) 'ticketId': ticketId,
    if (jobId != null) 'jobId': jobId,
    'resolved': resolved,
    if (resolvedByAdminId != null) 'resolvedByAdminId': resolvedByAdminId,
    'raisedAt': fs.Timestamp.fromDate(raisedAt),
    if (resolvedAt != null) 'resolvedAt': fs.Timestamp.fromDate(resolvedAt!),
  };

  factory SafetyAlert.fromMap(Map<String, dynamic> map) => SafetyAlert(
    id: map['id'] as String? ?? '',
    userId: map['userId'] as String? ?? '',
    ticketId: map['ticketId'] as String?,
    jobId: map['jobId'] as String?,
    resolved: map['resolved'] as bool? ?? false,
    resolvedByAdminId: map['resolvedByAdminId'] as String?,
    raisedAt: _dateFrom(map['raisedAt']),
    resolvedAt: map['resolvedAt'] == null ? null : _dateFrom(map['resolvedAt']),
  );

  SafetyAlert copyWith({
    bool? resolved,
    String? resolvedByAdminId,
    DateTime? resolvedAt,
  }) {
    return SafetyAlert(
      id: id,
      userId: userId,
      ticketId: ticketId,
      jobId: jobId,
      raisedAt: raisedAt,
      resolved: resolved ?? this.resolved,
      resolvedByAdminId: resolvedByAdminId ?? this.resolvedByAdminId,
      resolvedAt: resolvedAt ?? this.resolvedAt,
    );
  }
}

/// Tolerates both a Firestore [fs.Timestamp] and an ISO-8601 string, so
/// records written by the app and by the admin website both parse.
DateTime _dateFrom(Object? value) {
  if (value is fs.Timestamp) return value.toDate();
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}
