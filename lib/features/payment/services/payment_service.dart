import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../admin_panel/services/account_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/payment_model.dart';

/// Simulated payment — no real money moves, no real gateway is involved.
///
/// A payment always resolves to either [PaymentStatus.success] or
/// [PaymentStatus.failed] in a controlled way (via [forceFailure]) so the
/// failure/retry path can be demonstrated deliberately rather than relying
/// on chance.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  final Map<String, PaymentRecord> _records = {};

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

    if (record.status == PaymentStatus.success) {
      await JobService.instance.markPaid(jobId, record.id);
    }
    return record;
  }

  PaymentRecord? paymentForJob(String jobId) => _records[jobId];
}
