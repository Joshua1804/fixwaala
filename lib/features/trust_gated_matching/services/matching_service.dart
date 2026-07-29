import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseException;
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../../provider_dashboard/services/analytics_service.dart';
import '../../provider_verification/services/verification_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/candidate_lease.dart';

/// Implements the Trust-Gated Matching flow (Module 6 — core feature).
///
/// Multiple providers may accept the same ticket; each acceptance persists
/// a [CandidateLease] at `tickets/{ticketId}/candidates/{providerId}`. The
/// customer reviews the live list and confirms one, which reveals the
/// exact location to that provider only and marks the rest `notSelected`.
class MatchingService {
  MatchingService._();
  static final MatchingService instance = MatchingService._();

  // In-memory fallback: ticketId -> providerId -> lease.
  final Map<String, Map<String, CandidateLease>> _candidates = {};
  final StreamController<String> _changes =
      StreamController<String>.broadcast();

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> _candidatesCol(String ticketId) =>
      FirebaseService.instance.firestore
          .collection('tickets')
          .doc(ticketId)
          .collection('candidates');

  /// Clears all in-memory state. Test-only.
  @visibleForTesting
  void resetForTesting() {
    _candidates.clear();
  }

  /// Provider taps Accept: persists a candidate lease and, if this is the
  /// ticket's first candidate, opens the customer's review window.
  Future<CandidateLease?> acceptOpportunity({
    required String ticketId,
    required String providerId,
    AppUser? provider,
  }) async {
    final ticket = await TicketService.instance.watchTicket(ticketId).first;

    final providerLocation = provider?.providerProfile?.liveLocation;
    final distanceKm = providerLocation == null
        ? 0.0
        : LocationService.instance.distanceKm(
            providerLocation,
            ticket.approximateLocation,
          );
    // Rough ETA at an assumed ~30 km/h average urban travel speed.
    final etaMinutes = (distanceKm * 2).round().clamp(1, 999);

    final analytics = await AnalyticsService.instance.load(providerId);
    final verificationStatus = await VerificationService.instance.status(
      providerId,
    );

    final now = DateTime.now();
    final expiresAt = now.add(
      const Duration(seconds: AppConstants.candidateReviewSeconds),
    );
    final lease = CandidateLease(
      ticketId: ticketId,
      providerId: providerId,
      displayName: provider?.name ?? 'Provider',
      category: ticket.category,
      distanceKm: distanceKm,
      etaMinutes: etaMinutes,
      ratingAverage: analytics.ratingAverage,
      completedJobs: analytics.completedJobs,
      verified: verificationStatus == VerificationStatus.approved,
      leasedAt: now,
      expiresAt: expiresAt,
    );

    await _persistCandidate(lease);

    if (ticket.status == TicketStatus.matching) {
      await TicketService.instance.openCandidateWindow(ticketId, expiresAt);
    }

    return lease;
  }

  /// Provider taps Decline: no persistence needed — the ticket keeps
  /// broadcasting to every other online, in-range provider unaffected.
  /// The card is simply removed from this provider's own list locally.
  Future<void> declineOpportunity({
    required String ticketId,
    required String providerId,
  }) async {}

  /// Customer confirms → provider is officially assigned, exact location is
  /// revealed to them, every other candidate is marked not selected, and a
  /// Service Job Lifecycle (Module 7) record is created.
  Future<void> confirmProvider({
    required String ticketId,
    required String providerId,
    String? providerName,
    String? customerName,
    ServiceCategory? category,
  }) async {
    final ticket = await TicketService.instance.watchTicket(ticketId).first;
    final customer = await AuthService.instance.currentUser();

    await TicketService.instance.assignProvider(
      ticketId: ticketId,
      providerId: providerId,
      exactLocation: ticket.approximateLocation,
    );

    final candidates = await watchCandidates(ticketId).first;
    for (final candidate in candidates) {
      final status = candidate.providerId == providerId
          ? CandidateStatus.selected
          : CandidateStatus.notSelected;
      await _updateCandidateStatus(ticketId, candidate.providerId, status);
    }

    await JobService.instance.createJob(
      ticketId: ticketId,
      providerId: providerId,
      providerName: providerName ?? 'Provider',
      customerId: customer?.id ?? ticket.customerId,
      customerName: customerName ?? ticket.customerName,
      category: category ?? ticket.category,
    );
  }

  /// Marks a single candidate rejected/expired. If no candidate is left
  /// pending afterward, the ticket reverts to [TicketStatus.matching] so
  /// geo-broadcast resumes.
  Future<void> rejectCandidate({
    required String ticketId,
    required String providerId,
    CandidateStatus status = CandidateStatus.rejected,
  }) async {
    await _updateCandidateStatus(ticketId, providerId, status);

    final candidates = await watchCandidates(ticketId).first;
    final stillPending = candidates.any(
      (c) => c.status == CandidateStatus.pending,
    );
    if (!stillPending) {
      await TicketService.instance.updateStatus(
        ticketId,
        TicketStatus.matching,
      );
    }
  }

  /// Live updates of every candidate on [ticketId], oldest-accepted first.
  Stream<List<CandidateLease>> watchCandidates(String ticketId) {
    if (_live) {
      return _candidatesCol(ticketId).snapshots().map(
        (snap) => snap.docs.map((d) => CandidateLease.fromMap(d.data())).toList()
          ..sort((a, b) => a.leasedAt.compareTo(b.leasedAt)),
      );
    }

    late final StreamController<List<CandidateLease>> controller;
    StreamSubscription<String>? sub;
    void emit() {
      final list = (_candidates[ticketId]?.values.toList() ?? [])
        ..sort((a, b) => a.leasedAt.compareTo(b.leasedAt));
      controller.add(list);
    }

    controller = StreamController<List<CandidateLease>>(
      onListen: () {
        emit();
        sub = _changes.stream.where((id) => id == ticketId).listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  Future<void> _persistCandidate(CandidateLease lease) async {
    if (_live) {
      try {
        await _candidatesCol(
          lease.ticketId,
        ).doc(lease.providerId).set(lease.toMap());
      } on FirebaseException catch (e) {
        if (kDebugMode && e.code == 'permission-denied') {
          debugPrint(
            '[MatchingService] Firestore denied candidate write; '
            'continuing in local cache only.',
          );
          return;
        }
        rethrow;
      }
    } else {
      final forTicket = _candidates.putIfAbsent(lease.ticketId, () => {});
      forTicket[lease.providerId] = lease;
      _changes.add(lease.ticketId);
    }
  }

  Future<void> _updateCandidateStatus(
    String ticketId,
    String providerId,
    CandidateStatus status,
  ) async {
    if (_live) {
      try {
        await _candidatesCol(
          ticketId,
        ).doc(providerId).update({'status': status.name});
      } on FirebaseException catch (e) {
        if (kDebugMode && e.code == 'permission-denied') {
          debugPrint(
            '[MatchingService] Firestore denied candidate status update.',
          );
          return;
        }
        rethrow;
      }
    } else {
      final existing = _candidates[ticketId]?[providerId];
      if (existing != null) {
        _candidates[ticketId]![providerId] = existing.copyWith(status: status);
        _changes.add(ticketId);
      }
    }
  }
}
