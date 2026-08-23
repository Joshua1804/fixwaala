import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_facing_exception.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/session_scoped_sync.dart';
import '../../../core/services/account_service.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../models/job_model.dart';

/// Thrown when a requested job action is not valid for the job's current
/// [JobStatus]. Screens should catch this and show a helpful message
/// rather than letting the action silently fail.
class JobTransitionException implements UserFacingException {
  @override
  final String message;
  JobTransitionException(this.message);

  @override
  String toString() => message;
}

/// Owns the Service Job Lifecycle (Module 7) state machine.
///
/// Every read here is served synchronously from an in-memory cache
/// ([_jobs]) so the many call sites that read job state inside `build()`
/// keep working unchanged. When Firebase is configured, [initialize] opens
/// a live Firestore listener on the `jobs` collection that both hydrates
/// this cache on startup (fixing state disappearing on reload) and keeps
/// it in sync afterward; every mutation also writes through to Firestore.
/// Without Firebase configured, state lives in-memory for the lifetime of
/// the app process only.
class JobService {
  JobService._();
  static final JobService instance = JobService._();

  final Map<String, Job> _jobs = {};
  int _seq = 0;
  final StreamController<Job> _controller = StreamController<Job>.broadcast();

  late final SessionScopedSync _sync = SessionScopedSync(
    debugName: 'JobService',
    // A user is the customer on some jobs and the provider on others, and
    // Firestore cannot OR across two fields in one indexable query.
    queriesForUser: (uid) => [
      _col.where('customerId', isEqualTo: uid),
      _col.where('providerId', isEqualTo: uid),
    ],
    onChange: (change) {
      final job = Job.fromMap(change.doc.data()!);
      instance._jobs[job.jobId] = job;
      instance._controller.add(job);
    },
    onClear: () => instance._jobs.clear(),
  );

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('jobs');

  /// Binds the live Firestore sync to the signed-in user. Call once at app
  /// startup; it waits for auth itself. No-op in simulation mode.
  Future<void> initialize() => _sync.start();

  /// Ends the session sync and drops every cached job.
  Future<void> endSession() => _sync.stop();

  Future<void> _persist(Job job) async {
    if (!_live) return;
    await _col.doc(job.jobId).set(job.toMap());
  }

  /// Clears all in-memory state. Test-only.
  @visibleForTesting
  void resetForTesting() {
    _jobs.clear();
    _seq = 0;
  }

  // ── Creation ──────────────────────────────────────────────────────

  /// Creates a new job the moment a customer confirms a provider in
  /// Trust-Gated Matching. Status starts at [JobStatus.assigned].
  Future<Job> createJob({
    required String ticketId,
    required String providerId,
    required String providerName,
    required String customerId,
    required String customerName,
    required ServiceCategory category,
    String? customerPhone,
    String? providerPhone,
  }) async {
    _seq += 1;
    final now = DateTime.now();
    final job = Job(
      jobId: 'job-$_seq-${now.microsecondsSinceEpoch}',
      ticketId: ticketId,
      providerId: providerId,
      providerName: providerName,
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      providerPhone: providerPhone,
      category: category,
      status: JobStatus.assigned,
      history: [JobEventLogEntry(JobEvent.customerConfirmed, now)],
      createdAt: now,
    );
    _jobs[job.jobId] = job;
    _controller.add(job);
    unawaited(_persist(job));
    return job;
  }

  // ── Reads ─────────────────────────────────────────────────────────

  Job? jobById(String jobId) => _jobs[jobId];

  /// The job created for [ticketId], if any. A ticket only has a job once
  /// a provider has been confirmed (see [MatchingService.confirmProvider]),
  /// so this can legitimately return null for a ticket still matching.
  Job? jobForTicket(String ticketId) {
    for (final job in _jobs.values) {
      if (job.ticketId == ticketId) return job;
    }
    return null;
  }

  /// The customer's single most-recent still-active job, if any.
  Job? activeJobForCustomer(String customerId) {
    final matches = _jobs.values.where(
      (j) => j.customerId == customerId && j.isActive,
    );
    if (matches.isEmpty) return null;
    return matches.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }

  List<Job> activeJobsForProvider(String providerId) {
    final list = _jobs.values
        .where((j) => j.providerId == providerId && j.isActive)
        .toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  List<Job> completedJobsForProvider(String providerId) {
    final list = _jobs.values
        .where(
          (j) => j.providerId == providerId && j.status == JobStatus.completed,
        )
        .toList();
    list.sort(
      (a, b) => (b.completedAt ?? b.createdAt).compareTo(
        a.completedAt ?? a.createdAt,
      ),
    );
    return list;
  }

  /// Completed AND cancelled jobs — a provider's full history. Cancelled
  /// jobs are terminal (see [Job.isTerminal]) and would otherwise vanish
  /// from every list once an estimate is rejected or a job is withdrawn.
  List<Job> historyJobsForProvider(String providerId) {
    final list = _jobs.values
        .where((j) => j.providerId == providerId && j.isTerminal)
        .toList();
    list.sort(
      (a, b) =>
          (b.closedAt ?? b.createdAt).compareTo(a.closedAt ?? a.createdAt),
    );
    return list;
  }

  List<Job> allJobsForProvider(String providerId) =>
      _jobs.values.where((j) => j.providerId == providerId).toList();

  List<Job> allJobs() {
    final list = _jobs.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  /// Live updates for a single job. Emits the current value immediately
  /// (if it exists) followed by every subsequent change.
  Stream<Job> watchJob(String jobId) async* {
    final current = _jobs[jobId];
    if (current != null) yield current;
    yield* _controller.stream.where((j) => j.jobId == jobId);
  }

  /// Emits every time any job is created or changes. Used by list screens
  /// (Active Jobs, Admin Active Tickets) that need to rebuild whenever the
  /// underlying job set changes, without caring which job changed.
  Stream<Job> watchAllChanges() => _controller.stream;

  // ── Internal helpers ─────────────────────────────────────────────

  Job _require(String jobId) {
    final job = _jobs[jobId];
    if (job == null) {
      throw JobTransitionException('This job no longer exists.');
    }
    return job;
  }

  void _commit(Job updated) {
    _jobs[updated.jobId] = updated;
    _controller.add(updated);
    unawaited(_persist(updated));
    unawaited(_mirrorTicketStatus(updated));
  }

  /// Projects a job's state back onto its parent ticket.
  ///
  /// [TicketStatus] has fourteen values but only ever reached `assigned`:
  /// everything past that point is driven by [JobStatus], and nothing carried
  /// it across. Because `Ticket.isActive` is true for anything that is not
  /// completed/paid/closed/cancelled/failed, **every ticket a customer ever
  /// created stayed active forever** — the History tab could never populate
  /// and the Active list grew without bound.
  ///
  /// Every job transition funnels through [_commit], so mirroring here covers
  /// the whole state machine rather than each call site remembering to do it.
  Future<void> _mirrorTicketStatus(Job job) async {
    final mapped = _ticketStatusFor(job);
    try {
      await TicketService.instance.updateStatus(job.ticketId, mapped);
    } catch (error) {
      // A ticket that has been removed must not break the job it belonged to.
      debugPrint('[JobService] Could not mirror status to ticket: $error');
    }
  }

  /// The ticket status implied by a job's current state.
  ///
  /// Closure and payment outrank the lifecycle status: a completed job that
  /// has been paid for reads as `paid`, and one that is fully wrapped up
  /// reads as `closed`.
  static TicketStatus _ticketStatusFor(Job job) {
    if (job.status == JobStatus.cancelled) return TicketStatus.cancelled;
    if (job.closedAt != null) return TicketStatus.closed;
    if (job.paid) return TicketStatus.paid;

    return switch (job.status) {
      JobStatus.assigned => TicketStatus.assigned,
      JobStatus.accepted => TicketStatus.assigned,
      JobStatus.enRoute => TicketStatus.providerEnRoute,
      JobStatus.arrived => TicketStatus.providerArrived,
      JobStatus.checkedIn => TicketStatus.providerArrived,
      JobStatus.inspecting => TicketStatus.underInspection,
      JobStatus.estimateSubmitted => TicketStatus.awaitingEstimateApproval,
      JobStatus.workInProgress => TicketStatus.inProgress,
      JobStatus.completionRequested => TicketStatus.inProgress,
      JobStatus.completed => TicketStatus.completed,
      JobStatus.cancelled => TicketStatus.cancelled,
    };
  }

  void _requireStatus(Job job, JobStatus expected, String actionLabel) {
    if (job.status != expected) {
      throw JobTransitionException(
        '$actionLabel is not available while the job is ${_label(job.status)}.',
      );
    }
  }

  String _label(JobStatus s) => switch (s) {
    JobStatus.assigned => 'awaiting provider acceptance',
    JobStatus.accepted => 'accepted, not yet en route',
    JobStatus.enRoute => 'en route',
    JobStatus.arrived => 'arrived on site',
    JobStatus.checkedIn => 'checked in',
    JobStatus.inspecting => 'under inspection',
    JobStatus.estimateSubmitted => 'awaiting estimate approval',
    JobStatus.workInProgress => 'work in progress',
    JobStatus.completionRequested => 'awaiting completion confirmation',
    JobStatus.completed => 'completed',
    JobStatus.cancelled => 'cancelled',
  };

  // ── Provider-driven transitions ──────────────────────────────────

  Future<void> providerAccept(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.assigned, 'Accepting the job');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.accepted,
        acceptedAt: now,
        history: [...job.history, JobEventLogEntry(JobEvent.jobAccepted, now)],
      ),
    );
  }

  Future<void> providerReject(String jobId, {String? reason}) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.assigned, 'Rejecting the job');
    _cancel(job, event: JobEvent.jobRejected, reason: reason);
  }

  Future<void> startEnRoute(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.accepted, 'Starting travel');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.enRoute,
        enRouteAt: now,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.travelStarted, now),
        ],
      ),
    );
  }

  Future<void> markArrived(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.enRoute, 'Marking arrival');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.arrived,
        arrivedAt: now,
        history: [...job.history, JobEventLogEntry(JobEvent.arrived, now)],
      ),
    );
  }

  Future<void> checkIn(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.arrived, 'Checking in');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.checkedIn,
        history: [...job.history, JobEventLogEntry(JobEvent.checkedIn, now)],
      ),
    );
  }

  Future<void> startInspection(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.checkedIn, 'Starting inspection');
    _commit(job.copyWith(status: JobStatus.inspecting));
  }

  Future<void> submitEstimate(String jobId, RepairEstimate estimate) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.inspecting, 'Submitting an estimate');
    if (estimate.diagnosis.trim().isEmpty) {
      throw JobTransitionException('Enter a diagnosis before submitting.');
    }
    if (estimate.total <= 0) {
      throw JobTransitionException('Estimate total must be greater than zero.');
    }
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.estimateSubmitted,
        estimate: estimate,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.inspectionSubmitted, now),
        ],
      ),
    );
  }

  Future<void> requestCompletion(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.providerId);
    _requireStatus(job, JobStatus.workInProgress, 'Requesting completion');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.completionRequested,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.completionRequested, now),
        ],
      ),
    );
  }

  // ── Customer-driven transitions ──────────────────────────────────

  Future<void> approveEstimate(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.customerId);
    _requireStatus(job, JobStatus.estimateSubmitted, 'Approving the estimate');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.workInProgress,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.estimateAccepted, now),
          JobEventLogEntry(JobEvent.workStarted, now),
        ],
      ),
    );
  }

  Future<void> rejectEstimate(String jobId, {String? reason}) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.customerId);
    _requireStatus(job, JobStatus.estimateSubmitted, 'Rejecting the estimate');
    final now = DateTime.now();
    _cancel(
      job.copyWith(
        estimateRejectionReason: reason,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.estimateRejected, now),
        ],
      ),
      event: JobEvent.estimateRejected,
      reason: reason,
      alreadyLogged: true,
    );
  }

  Future<void> confirmCompletion(String jobId) async {
    final job = _require(jobId);
    AccountService.instance.assertActive(job.customerId);
    _requireStatus(job, JobStatus.completionRequested, 'Confirming completion');
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.completed,
        completedAt: now,
        history: [
          ...job.history,
          JobEventLogEntry(JobEvent.workCompleted, now),
          JobEventLogEntry(JobEvent.customerConfirmed, now),
        ],
      ),
    );
  }

  // ── Cross-cutting: payment, ratings, reports, safety ─────────────

  Future<void> markPaid(String jobId, String paymentId) async {
    final job = _require(jobId);
    _requireStatus(job, JobStatus.completed, 'Recording payment');
    _commit(job.copyWith(paid: true, paymentId: paymentId));
    _maybeClose(jobId);
  }

  Future<void> markRated(
    String jobId, {
    required RatingDirection direction,
  }) async {
    final job = _require(jobId);
    if (direction == RatingDirection.customerToProvider) {
      _commit(job.copyWith(customerRated: true));
    } else {
      _commit(job.copyWith(providerRated: true));
    }
    _maybeClose(jobId);
  }

  /// Closes a job once nothing is outstanding on either side.
  ///
  /// This previously ignored [Job.providerRated], so a job closed as soon as
  /// the customer rated — while the provider was still being offered "Rate
  /// customer" on a job the app considered finished. Closure now means what
  /// it says: work done, money settled, both parties have had their say.
  void _maybeClose(String jobId) {
    final job = _require(jobId);
    if (job.status == JobStatus.completed &&
        job.paid &&
        job.customerRated &&
        job.providerRated &&
        job.closedAt == null) {
      _commit(job.copyWith(closedAt: DateTime.now()));
    }
  }

  Future<void> flagReport(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return; // Reports can reference tickets without a job.
    _commit(job.copyWith(hasOpenReport: true));
  }

  Future<void> flagSafetyAlert(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return;
    _commit(job.copyWith(hasSafetyAlert: true));
  }

  /// Cancels a job from any non-terminal state (e.g. customer withdraws,
  /// provider rejects, estimate is declined). Terminal states cannot be
  /// re-cancelled.
  Future<void> cancelJob(String jobId, {String? reason}) async {
    final job = _require(jobId);
    if (job.isTerminal) {
      throw JobTransitionException(
        'This job is already ${_label(job.status)}.',
      );
    }
    _cancel(job, event: JobEvent.cancelled, reason: reason);
  }

  void _cancel(
    Job job, {
    required JobEvent event,
    String? reason,
    bool alreadyLogged = false,
  }) {
    final now = DateTime.now();
    _commit(
      job.copyWith(
        status: JobStatus.cancelled,
        cancellationReason: reason,
        closedAt: now,
        history: alreadyLogged
            ? job.history
            : [...job.history, JobEventLogEntry(event, now)],
      ),
    );
  }
}
