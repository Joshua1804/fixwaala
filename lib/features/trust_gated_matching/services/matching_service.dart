import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../auth/services/auth_service.dart';
import '../../geo_broadcast/models/provider_match.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/candidate_lease.dart';

/// Implements the Trust-Gated Matching flow (Module 6 — core feature).
///
/// Backend rules:
///   • First provider to accept wins an atomic lease.
///   • Lease auto-expires after `AppConstants.candidateReviewSeconds`.
///   • Customer must confirm inside the lease window; otherwise matching resumes.
///   • Exact customer address is only revealed after customer confirms.
class MatchingService {
  MatchingService._();
  static final MatchingService instance = MatchingService._();

  /// Provider taps Accept: request an atomic lease.
  Future<CandidateLease?> acceptOpportunity({
    required String ticketId,
    required String providerId,
  }) async {
    // TODO: Cloud Function / Firestore transaction that:
    //   • Ensures ticket status == matching
    //   • Ensures no active lease exists
    //   • Writes lease doc with TTL
    final now = DateTime.now();
    return CandidateLease(
      ticketId: ticketId,
      providerId: providerId,
      leasedAt: now,
      expiresAt: now.add(
        const Duration(seconds: AppConstants.candidateReviewSeconds),
      ),
    );
  }

  /// Customer confirms → provider is officially assigned + exact address
  /// revealed, and a Service Job Lifecycle (Module 7) record is created so
  /// the customer's Job Tracking screen has something to show.
  Future<void> confirmProvider({
    required String ticketId,
    required String providerId,
    String? providerName,
    String? customerName,
    ServiceCategory? category,
  }) async {
    // TODO: transaction — assign provider, transition ticket status, share address.
    final customer = await AuthService.instance.currentUser();
    await JobService.instance.createJob(
      ticketId: ticketId,
      providerId: providerId,
      providerName: providerName ?? 'Your provider',
      customerId: customer?.id ?? 'demo-customer',
      customerName: customerName ?? customer?.name ?? 'Customer',
      category: category ?? ServiceCategory.plumber,
    );
  }

  /// Customer rejects OR timer expires → clear lease, resume broadcast.
  Future<void> rejectCandidate({
    required String ticketId,
    required String providerId,
  }) async {
    // TODO: clear lease, resume broadcast (Module 5).
  }

  Stream<ProviderCandidate?> watchPendingCandidate(String ticketId) async* {
    // TODO: Firestore stream — emit the current pending candidate profile, or null.
  }
}
