import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_facing_exception.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/eta_estimate.dart';
import '../../../core/services/location_service.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../../provider_dashboard/services/analytics_service.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/candidate_lease.dart';

/// Thrown when two customers (or two taps) race for the same provider.
class MatchingConflictException implements UserFacingException {
  @override
  final String message;
  MatchingConflictException(this.message);

  @override
  String toString() => message;
}

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
    // Not yet the assigned provider, so the private `tickets/{id}` document
    // (which carries the customer's exact location) is off limits — the
    // security rules only grant that once assigned. The redacted broadcast
    // projection has everything accepting needs.
    final ticket = await TicketService.instance.getOpenTicket(ticketId);

    final providerLocation = provider?.providerProfile?.liveLocation;
    final distanceKm = providerLocation == null
        ? 0.0
        : LocationService.instance.distanceKm(
            providerLocation,
            ticket.approximateLocation,
          );
    final etaMinutes = EtaEstimate.minutesFor(distanceKm);

    final analytics = await AnalyticsService.instance.load(providerId);

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
      // Granted by an administrator in the admin website; the app only reads it.
      verified: provider?.isVerified ?? false,
      phone: provider?.phone,
      leasedAt: now,
      expiresAt: expiresAt,
    );

    await _persistCandidate(lease);

    if (ticket.status == TicketStatus.matching) {
      await TicketService.instance.openCandidateWindow(ticketId, expiresAt);
    }

    return lease;
  }

  /// Provider taps Decline.
  ///
  /// This was an empty method body: the card disappeared only because the
  /// widget set a local `_declined` flag, so the same ticket reappeared on the
  /// next stream emission and again on every app restart. The decline is now
  /// recorded at `tickets/{id}/candidates/{providerId}` with status
  /// [CandidateStatus.rejected], and [declinedTicketIds] filters those out of
  /// the provider's feed for good.
  Future<void> declineOpportunity({
    required String ticketId,
    required String providerId,
  }) async {
    final now = DateTime.now();
    final decline = CandidateLease(
      ticketId: ticketId,
      providerId: providerId,
      displayName: '',
      category: ServiceCategory.unknown,
      distanceKm: 0,
      etaMinutes: 0,
      ratingAverage: 0,
      completedJobs: 0,
      verified: false,
      leasedAt: now,
      expiresAt: now,
      status: CandidateStatus.rejected,
    );
    await _persistCandidate(decline);
    _declinedByProvider.putIfAbsent(providerId, () => <String>{}).add(ticketId);
  }

  /// Tickets [providerId] has already declined, so the broadcast feed can
  /// exclude them. Firestore has no "not in this collection group" query, so
  /// the set is read once per session and kept current locally.
  final Map<String, Set<String>> _declinedByProvider = {};

  Set<String> declinedTicketIds(String providerId) =>
      _declinedByProvider[providerId] ?? const {};

  /// Loads this provider's past declines. Called when the provider goes
  /// online so a restart does not resurface everything they already refused.
  Future<void> loadDeclines(String providerId) async {
    if (!_live) return;
    try {
      final snap = await FirebaseService.instance.firestore
          .collectionGroup('candidates')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: CandidateStatus.rejected.name)
          .get();
      _declinedByProvider[providerId] = snap.docs
          .map((d) => d.data()['ticketId'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (error) {
      debugPrint('[MatchingService] Could not load declines: $error');
    }
  }

  /// Customer confirms → provider is officially assigned, exact location is
  /// revealed to them, every other candidate is marked not selected, and a
  /// Service Job Lifecycle (Module 7) record is created.
  ///
  /// Returns the created [Job] so the caller can navigate straight to it.
  /// This used to return nothing, leaving the review screen to push
  /// `jobTracking` with no arguments and hope the destination could find the
  /// job by scanning every job held in memory.
  ///
  /// The candidate updates run as a single [WriteBatch]. Previously each of
  /// the four writes went out independently, so an app killed midway left a
  /// ticket marked `assigned` with no job attached, or half the losing
  /// candidates still showing as pending.
  Future<Job> confirmProvider({
    required String ticketId,
    required String providerId,
    String? providerName,
    String? customerName,
    ServiceCategory? category,
  }) async {
    final ticket = await TicketService.instance.watchTicket(ticketId).first;

    // Guards a double-tap and a genuine race between two devices: whoever
    // gets here second finds the ticket already spoken for.
    if (ticket.assignedProviderId != null &&
        ticket.assignedProviderId != providerId) {
      throw MatchingConflictException(
        'This request has already been assigned to another provider.',
      );
    }

    final customer = await AuthService.instance.currentUser();

    await TicketService.instance.assignProvider(
      ticketId: ticketId,
      providerId: providerId,
      exactLocation: ticket.approximateLocation,
    );

    final candidates = await watchCandidates(ticketId).first;
    await _settleCandidates(ticketId, candidates, winnerId: providerId);

    // Carry both contact numbers onto the job. Neither party can read the
    // other's user document, so this is the only point at which they can be
    // paired — the provider supplied theirs on the lease, the customer
    // supplies their own here.
    final winner = candidates
        .where((c) => c.providerId == providerId)
        .firstOrNull;

    return JobService.instance.createJob(
      ticketId: ticketId,
      providerId: providerId,
      providerName: providerName ?? 'Provider',
      customerId: customer?.id ?? ticket.customerId,
      customerName: customerName ?? ticket.customerName,
      customerPhone: customer?.phone,
      providerPhone: winner?.phone,
      category: category ?? ticket.category,
    );
  }

  /// Marks the winner selected and everyone else not-selected in one atomic
  /// write, rather than a sequential loop of individual updates.
  Future<void> _settleCandidates(
    String ticketId,
    List<CandidateLease> candidates, {
    required String winnerId,
  }) async {
    CandidateStatus statusFor(CandidateLease c) => c.providerId == winnerId
        ? CandidateStatus.selected
        : CandidateStatus.notSelected;

    if (!_live) {
      for (final candidate in candidates) {
        final existing = _candidates[ticketId]?[candidate.providerId];
        if (existing != null) {
          _candidates[ticketId]![candidate.providerId] = existing.copyWith(
            status: statusFor(candidate),
          );
        }
      }
      _changes.add(ticketId);
      return;
    }

    final batch = FirebaseService.instance.firestore.batch();
    for (final candidate in candidates) {
      batch.update(_candidatesCol(ticketId).doc(candidate.providerId), {
        'status': statusFor(candidate).name,
      });
    }
    await batch.commit();
  }

  /// Expires every still-pending candidate on [ticketId] in one write and
  /// returns the ticket to matching.
  ///
  /// The caller previously looped [rejectCandidate], and each iteration
  /// re-read the whole candidate list to decide whether any were still
  /// pending — O(n²) reads to expire n candidates, with the ticket status
  /// flapping on every pass.
  Future<void> expireAllPending(String ticketId) async {
    final candidates = await watchCandidates(ticketId).first;
    final pending = candidates
        .where((c) => c.status == CandidateStatus.pending)
        .toList();

    if (pending.isNotEmpty) {
      if (_live) {
        final batch = FirebaseService.instance.firestore.batch();
        for (final candidate in pending) {
          batch.update(_candidatesCol(ticketId).doc(candidate.providerId), {
            'status': CandidateStatus.expired.name,
          });
        }
        await batch.commit();
      } else {
        for (final candidate in pending) {
          final existing = _candidates[ticketId]?[candidate.providerId];
          if (existing != null) {
            _candidates[ticketId]![candidate.providerId] = existing.copyWith(
              status: CandidateStatus.expired,
            );
          }
        }
        _changes.add(ticketId);
      }
    }

    await TicketService.instance.updateStatus(ticketId, TicketStatus.matching);
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
        (snap) =>
            snap.docs.map((d) => CandidateLease.fromMap(d.data())).toList()
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
        sub = _changes.stream
            .where((id) => id == ticketId)
            .listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// Live view of [providerId]'s own candidacy on [ticketId], if any. Lets a
  /// provider's own opportunity card react to their pending/settled status
  /// instead of continuing to show Accept/Decline after they've already
  /// acted — previously the card had no idea an accept had gone through, so
  /// a provider could tap Decline on a ticket they'd just accepted.
  Stream<CandidateLease?> watchMyLease(String ticketId, String providerId) {
    if (_live) {
      return _candidatesCol(ticketId)
          .doc(providerId)
          .snapshots()
          .map(
            (snap) => snap.exists ? CandidateLease.fromMap(snap.data()!) : null,
          );
    }

    late final StreamController<CandidateLease?> controller;
    StreamSubscription<String>? sub;
    void emit() => controller.add(_candidates[ticketId]?[providerId]);

    controller = StreamController<CandidateLease?>(
      onListen: () {
        emit();
        sub = _changes.stream
            .where((id) => id == ticketId)
            .listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  /// [providerId]'s leases currently sitting at [CandidateStatus.notSelected]
  /// — i.e. every ticket where a customer confirmed someone else. The caller
  /// (see `_CandidateOutcomeNotifier` in the provider home screen) diffs this
  /// against what it has already announced, the same seed-then-diff shape
  /// used for new-ticket alerts: without seeding, every app restart would
  /// re-announce every loss a provider has ever taken.
  Stream<List<CandidateLease>> watchMyOutcomes(String providerId) {
    if (_live) {
      return FirebaseService.instance.firestore
          .collectionGroup('candidates')
          .where('providerId', isEqualTo: providerId)
          .where('status', isEqualTo: CandidateStatus.notSelected.name)
          .snapshots()
          .map(
            (snap) =>
                snap.docs.map((d) => CandidateLease.fromMap(d.data())).toList(),
          );
    }

    late final StreamController<List<CandidateLease>> controller;
    StreamSubscription<String>? sub;
    void emit() {
      final outcomes = <CandidateLease>[];
      for (final forTicket in _candidates.values) {
        final lease = forTicket[providerId];
        if (lease != null && lease.status == CandidateStatus.notSelected) {
          outcomes.add(lease);
        }
      }
      controller.add(outcomes);
    }

    controller = StreamController<List<CandidateLease>>(
      onListen: () {
        emit();
        sub = _changes.stream.listen((_) => emit());
      },
      onCancel: () => sub?.cancel(),
    );
    return controller.stream;
  }

  Future<void> _persistCandidate(CandidateLease lease) async {
    if (_live) {
      await _candidatesCol(
        lease.ticketId,
      ).doc(lease.providerId).set(lease.toMap());
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
      await _candidatesCol(
        ticketId,
      ).doc(providerId).update({'status': status.name});
    } else {
      final existing = _candidates[ticketId]?[providerId];
      if (existing != null) {
        _candidates[ticketId]![providerId] = existing.copyWith(status: status);
        _changes.add(ticketId);
      }
    }
  }
}
