import '../../../core/models/enums.dart';

class Report {
  final String id;
  final String reporterId;
  final String? againstUserId;
  final String? ticketId;
  final String reason;
  final String description;
  final List<String> evidenceUrls;
  final ReportSeverity severity;
  final bool resolved;
  final DateTime createdAt;

  const Report({
    required this.id,
    required this.reporterId,
    required this.reason,
    required this.description,
    required this.evidenceUrls,
    required this.severity,
    required this.resolved,
    required this.createdAt,
    this.againstUserId,
    this.ticketId,
  });
}

class SafetyAlert {
  final String id;
  final String userId;
  final String? ticketId;
  final DateTime raisedAt;

  const SafetyAlert({
    required this.id,
    required this.userId,
    required this.raisedAt,
    this.ticketId,
  });
}
