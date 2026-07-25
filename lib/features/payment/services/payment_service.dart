import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart'
    show CollectionReference, FirebaseException;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../admin_panel/services/account_service.dart';
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
  StreamSubscription? _liveSub;

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('payments');

  /// Opens the live Firestore sync. Call once at app startup. No-op in
  /// simulation mode.
  Future<void> initialize() async {
    if (!_live) return;
    await _liveSub?.cancel();
    _liveSub = _col.snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final record = PaymentRecord.fromMap(change.doc.data()!);
        _records[record.jobId] = record;
      }
    });
  }

  Future<void> _persist(PaymentRecord record) async {
    if (!_live) return;
    try {
      await _col.doc(record.jobId).set(record.toMap());
    } on FirebaseException catch (e) {
      if (kDebugMode && e.code == 'permission-denied') {
        debugPrint(
          '[PaymentService] Firestore denied payment write; continuing in '
          'local cache only. Update Firestore rules before release.',
        );
        return;
      }
      rethrow;
    }
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
    await Future.delayed(const Duration(seconds: 2));

    final now = DateTime.now();
    final record = PaymentRecord(
      id: 'pay-${now.microsecondsSinceEpoch}',
      jobId: jobId,
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
