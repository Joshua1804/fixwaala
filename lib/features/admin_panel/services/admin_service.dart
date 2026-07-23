import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../reports_safety/services/report_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/admin_model.dart';
import 'account_service.dart';

/// Admin Panel (Module 12) — dashboard summary, account moderation, and the
/// audit trail. Deliberately has no Aadhaar/selfie verification surface;
/// [reviewProviderVerification] is retained only because Module 2's existing
/// provider-verification screen still calls it — nothing here links to it.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final List<AuditEvent> _auditLog = [];

  @visibleForTesting
  void resetForTesting() => _auditLog.clear();

  Future<bool> loginWithCredentials(String email, String password) async {
    // Demo bypass while no Firebase project is configured.
    if (email.trim().toLowerCase() == AppConstants.demoAdminEmail &&
        password == AppConstants.demoAdminPassword) {
      return true;
    }
    // TODO: Firebase Auth email/password + custom-claim check for admin.
    return false;
  }

  Future<AdminDashboardSummary> dashboardSummary() async {
    final jobs = JobService.instance.allJobs();
    return AdminDashboardSummary(
      activeTickets: jobs.where((j) => j.isActive).length,
      completedJobs: jobs.where((j) => j.status == JobStatus.completed).length,
      // TODO: source from Module 5 once geo-broadcast failures are persisted.
      matchingFailures: 0,
      openReports: ReportService.instance.openReports().length,
      highSeverityAlerts: ReportService.instance
          .unresolvedSafetyAlerts()
          .length,
      suspendedAccounts: AccountService.instance.countByStatus(
        AccountStatus.suspended,
      ),
    );
  }

  Future<void> reviewProviderVerification({
    required String providerId,
    required VerificationStatus decision,
    String? note,
  }) async {
    // TODO: update verification doc + audit event. Owned by Module 2.
  }

  Future<void> restrictAccount(
    String userId, {
    required String adminId,
    required String reason,
  }) async {
    await AccountService.instance.restrict(userId, reason: reason);
    await logAudit(
      AuditEvent(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        actorAdminId: adminId,
        action: 'restrictAccount',
        targetId: userId,
        payload: {'reason': reason},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> suspendAccount(
    String userId, {
    required String adminId,
    required String reason,
  }) async {
    await AccountService.instance.suspend(userId, reason: reason);
    await logAudit(
      AuditEvent(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        actorAdminId: adminId,
        action: 'suspendAccount',
        targetId: userId,
        payload: {'reason': reason},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> restoreAccount(String userId, {required String adminId}) async {
    await AccountService.instance.restore(userId);
    await logAudit(
      AuditEvent(
        id: 'audit-${DateTime.now().microsecondsSinceEpoch}',
        actorAdminId: adminId,
        action: 'restoreAccount',
        targetId: userId,
        payload: const {},
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> logAudit(AuditEvent event) async {
    _auditLog.add(event);
  }

  List<AuditEvent> auditEvents() {
    final list = List<AuditEvent>.from(_auditLog);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }
}
