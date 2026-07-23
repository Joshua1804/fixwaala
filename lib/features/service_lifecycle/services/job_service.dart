import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../admin_panel/services/account_service.dart';
import '../models/job_model.dart';

/// Thrown when a requested job action is not valid for the job's current
/// [JobStatus]. Screens should catch this and show a helpful message
/// rather than letting the action silently fail.
class JobTransitionException implements Exception {
  final String message;
  JobTransitionException(this.message);

  @override
  String toString() => message;
}

/// Owns the Service Job Lifecycle (Module 7) state machine.
///
/// Firebase-ready: every method is structured so the in-memory map can be
/// swapped for Firestore reads/writes without changing call sites. While no
/// Firebase project is configured, state lives in-memory for the lifetime
/// of the app process — which is sufficient to demo the full customer ↔
/// provider ↔ admin flow within a single running instance.
class JobService {
  JobService._();
  static final JobService instance = JobService._();

  final Map<String, Job> _jobs = {};
  int _seq = 0;
  final StreamController<Job> _controller = StreamController<Job>.broadcast();

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
      category: category,
      status: JobStatus.assigned,
      history: [JobEventLogEntry(JobEvent.customerConfirmed, now)],
      createdAt: now,
    );
    _jobs[job.jobId] = job;
    _controller.add(job);
    return job;
  }

  // ── Reads ─────────────────────────────────────────────────────────

  Job? jobById(String jobId) => _jobs[jobId];

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

  void _maybeClose(String jobId) {
    final job = _require(jobId);
    if (job.status == JobStatus.completed &&
        job.paid &&
        job.customerRated &&
        job.closedAt == null) {
      _commit(job.copyWith(closedAt: DateTime.now()));
    }
  }

  Future<void> flagReport(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return; // Reports can reference tickets without a job.
    _commit(job.copyWith(hasOpenReport: true));
  }

  Future<void> clearReportFlag(String jobId) async {
    final job = _jobs[jobId];
    if (job == null) return;
    _commit(job.copyWith(hasOpenReport: false));
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
