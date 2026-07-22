import '../../../core/models/enums.dart';
import '../models/admin_model.dart';

class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  Future<bool> loginWithCredentials(String email, String password) async {
    // TODO: Firebase Auth email/password + custom-claim check for admin.
    return false;
  }

  Future<AdminDashboardSummary> dashboardSummary() async {
    return AdminDashboardSummary.empty;
  }

  Future<void> reviewProviderVerification({
    required String providerId,
    required VerificationStatus decision,
    String? note,
  }) async {
    // TODO: update verification doc + audit event.
  }

  Future<void> restrictAccount(String userId, {required Duration duration}) async {
    // TODO
  }

  Future<void> suspendAccount(String userId) async {
    // TODO
  }

  Future<void> logAudit(AuditEvent event) async {
    // TODO
  }
}
