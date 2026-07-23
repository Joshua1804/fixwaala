class AuditEvent {
  final String id;
  final String actorAdminId;
  final String action; // e.g. 'suspendAccount', 'resolveReport'
  final String? targetId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.actorAdminId,
    required this.action,
    required this.payload,
    required this.createdAt,
    this.targetId,
  });
}

/// Top-line counts shown on the Admin Dashboard.
///
/// Deliberately excludes anything related to Aadhaar/selfie identity
/// verification — that remains a separate concern outside this panel.
class AdminDashboardSummary {
  final int activeTickets;
  final int completedJobs;
  final int matchingFailures;
  final int openReports;
  final int highSeverityAlerts;
  final int suspendedAccounts;

  const AdminDashboardSummary({
    required this.activeTickets,
    required this.completedJobs,
    required this.matchingFailures,
    required this.openReports,
    required this.highSeverityAlerts,
    required this.suspendedAccounts,
  });

  static const empty = AdminDashboardSummary(
    activeTickets: 0,
    completedJobs: 0,
    matchingFailures: 0,
    openReports: 0,
    highSeverityAlerts: 0,
    suspendedAccounts: 0,
  );
}
