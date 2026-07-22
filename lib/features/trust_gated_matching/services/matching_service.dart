import '../../../core/constants/app_constants.dart';
import '../../geo_broadcast/models/provider_match.dart';
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
      expiresAt:
          now.add(const Duration(seconds: AppConstants.candidateReviewSeconds)),
    );
  }

  /// Customer confirms → provider is officially assigned + exact address revealed.
  Future<void> confirmProvider({
    required String ticketId,
    required String providerId,
  }) async {
    // TODO: transaction — assign provider, transition ticket status, share address.
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
