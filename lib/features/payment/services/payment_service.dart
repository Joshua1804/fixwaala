import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show CollectionReference;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/session_scoped_sync.dart';
import '../../../core/services/account_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/payment_model.dart';

/// Simulated payment — no real money moves, no real gateway is involved.
///
/// A payment always resolves to either [PaymentStatus.success] or
/// [PaymentStatus.failed] in a controlled way (via [forceFailure]) so the
/// failure/retry path can be demonstrated deliberately rather than relying
/// on chance. Records are cached in-memory (so earnings lookups stay
/// synchronous) and mirrored to the `payments` Firestore collection when
/// configured, so earnings survive a reload.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final Map<String, PaymentRecord> _records = {}; // jobId -> record
  late final SessionScopedSync _sync = SessionScopedSync(
    debugName: 'PaymentService',
    queriesForUser: (uid) => [
      _col.where('customerId', isEqualTo: uid),
      _col.where('providerId', isEqualTo: uid),
    ],
    onChange: (change) {
      final record = PaymentRecord.fromMap(change.doc.data()!);
      instance._records[record.jobId] = record;
    },
    onClear: () => instance._records.clear(),
  );

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('payments');

  /// Binds the live Firestore sync to the signed-in user. Call once at app
  /// startup; it waits for auth itself. No-op in simulation mode.
  Future<void> initialize() => _sync.start();

  /// Ends the session sync and drops every cached payment.
  Future<void> endSession() => _sync.stop();

  Future<void> _persist(PaymentRecord record) async {
    if (!_live) return;
    await _col.doc(record.jobId).set(record.toMap());
  }

  @visibleForTesting
  void resetForTesting() => _records.clear();

  Future<PaymentRecord> simulate({
    required String jobId,
    required double amount,
    required String method,
    bool forceFailure = false,
  }) async {
    if (amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    final job = JobService.instance.jobById(jobId);
    if (job == null) {
      throw ArgumentError('This job no longer exists.');
    }
    if (job.status != JobStatus.completed) {
      throw StateError('Payment is only available once the job is completed.');
    }
    AccountService.instance.assertActive(job.customerId);

    // A deliberate stall so the demo payment feels like a real gateway
    // round trip. Debug only — this used to run unconditionally, adding two
    // seconds to every payment in a release build.
    if (kDebugMode) {
      await Future.delayed(const Duration(seconds: 2));
    }

    final now = DateTime.now();
    final record = PaymentRecord(
      id: 'pay-${now.microsecondsSinceEpoch}',
      jobId: jobId,
      customerId: job.customerId,
      providerId: job.providerId,
      amount: amount,
      method: method,
      status: forceFailure ? PaymentStatus.failed : PaymentStatus.success,
      failureReason: forceFailure
          ? 'Bank declined the transaction (demo).'
          : null,
      processedAt: now,
    );
    _records[jobId] = record;
    unawaited(_persist(record));

    if (record.status == PaymentStatus.success) {
      await JobService.instance.markPaid(jobId, record.id);
    }
    return record;
  }

  PaymentRecord? paymentForJob(String jobId) => _records[jobId];
}
