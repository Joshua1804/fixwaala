import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../auth/services/auth_service.dart';
import '../../geo_broadcast/models/provider_match.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/candidate_lease.dart';

/// Implements the Trust-Gated Matching flow (Module 6 — core feature).
class MatchingService {
  MatchingService._();
  static final MatchingService instance = MatchingService._();

  // Active lease storage (in-memory simulation)
  CandidateLease? _activeLease;
  AppUser? _activeProvider;

  CandidateLease? get activeLease => _activeLease;
  AppUser? get activeProvider => _activeProvider;

  /// Provider taps Accept: request an atomic lease.
  Future<CandidateLease?> acceptOpportunity({
    required String ticketId,
    required String providerId,
    AppUser? provider,
  }) async {
    final now = DateTime.now();
    _activeProvider = provider;
    _activeLease = CandidateLease(
      ticketId: ticketId,
      providerId: providerId,
      leasedAt: now,
      expiresAt: now.add(
        const Duration(seconds: AppConstants.candidateReviewSeconds),
      ),
    );
    return _activeLease;
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
    final customer = await AuthService.instance.currentUser();
    final pName = providerName ?? _activeProvider?.name ?? 'Joshua George';
    final pId = providerId.isNotEmpty && providerId != AppConstants.demoProviderId
        ? providerId
        : (_activeProvider?.id ?? AppConstants.demoProviderId);

    await JobService.instance.createJob(
      ticketId: ticketId,
      providerId: pId,
      providerName: pName,
      customerId: customer?.id ?? 'demo-customer',
      customerName: customerName ?? customer?.name ?? 'Sovin Somy',
      category: category ?? ServiceCategory.plumber,
    );
    _activeLease = null;
    _activeProvider = null;
  }

  /// Customer rejects OR timer expires → clear lease, resume broadcast.
  Future<void> rejectCandidate({
    required String ticketId,
    required String providerId,
  }) async {
    _activeLease = null;
    _activeProvider = null;
  }

  Stream<ProviderCandidate?> watchPendingCandidate(String ticketId) async* {
    if (_activeProvider != null) {
      yield ProviderCandidate(
        providerId: _activeProvider!.id,
        displayName: _activeProvider!.name ?? 'Joshua George',
        category: ServiceCategory.plumber,
        distanceKm: 1.2,
        etaMinutes: 8,
        ratingAverage: 4.8,
        completedJobs: 132,
        verified: true,
        location: const GeoPoint(0, 0),
      );
    } else {
      yield null;
    }
  }
}
