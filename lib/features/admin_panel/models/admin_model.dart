class AuditEvent {
  final String id;
  final String actorAdminId;
  final String action; // e.g. 'approveVerification', 'suspendUser'
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  const AuditEvent({
    required this.id,
    required this.actorAdminId,
    required this.action,
    required this.payload,
    required this.createdAt,
  });
}

class AdminDashboardSummary {
  final int pendingVerifications;
  final int activeTickets;
  final int matchingFailures;
  final int openReports;
  final int safetyAlerts;

  const AdminDashboardSummary({
    required this.pendingVerifications,
    required this.activeTickets,
    required this.matchingFailures,
    required this.openReports,
    required this.safetyAlerts,
  });

  static const empty = AdminDashboardSummary(
    pendingVerifications: 0,
    activeTickets: 0,
    matchingFailures: 0,
    openReports: 0,
    safetyAlerts: 0,
  );
}
