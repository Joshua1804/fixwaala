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
