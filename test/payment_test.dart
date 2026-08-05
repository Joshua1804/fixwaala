import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/services/account_service.dart';
import 'package:fixwaala/features/payment/services/payment_service.dart';
import 'package:fixwaala/features/service_lifecycle/models/job_model.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
    PaymentService.instance.resetForTesting();
    AccountService.instance.resetForTesting();
  });

  Future<String> completedJob() async {
    final job = await JobService.instance.createJob(
      ticketId: 't1',
      providerId: 'p1',
      providerName: 'Provider',
      customerId: 'c1',
      customerName: 'Customer',
      category: ServiceCategory.electrician,
    );
    await JobService.instance.providerAccept(job.jobId);
    await JobService.instance.startEnRoute(job.jobId);
    await JobService.instance.markArrived(job.jobId);
    await JobService.instance.checkIn(job.jobId);
    await JobService.instance.startInspection(job.jobId);
    await JobService.instance.submitEstimate(
      job.jobId,
      RepairEstimate(
        diagnosis: 'x',
        laborCharge: 100,
        partsCharge: 50,
        submittedAt: DateTime.now(),
      ),
    );
    await JobService.instance.approveEstimate(job.jobId);
    await JobService.instance.requestCompletion(job.jobId);
    await JobService.instance.confirmCompletion(job.jobId);
    return job.jobId;
  }

  group('Simulated payment outcomes', () {
    test('a successful payment marks the job as paid', () async {
      final jobId = await completedJob();
      final record = await PaymentService.instance.simulate(
        jobId: jobId,
        amount: 150,
        method: 'upi',
      );
      expect(record.status, PaymentStatus.success);
      expect(JobService.instance.jobById(jobId)!.paid, isTrue);
    });

    test('a controlled failure does not mark the job as paid', () async {
      final jobId = await completedJob();
      final record = await PaymentService.instance.simulate(
        jobId: jobId,
        amount: 150,
        method: 'card',
        forceFailure: true,
      );
      expect(record.status, PaymentStatus.failed);
      expect(record.failureReason, isNotNull);
      expect(JobService.instance.jobById(jobId)!.paid, isFalse);
    });

    test('retrying after a failure can succeed', () async {
      final jobId = await completedJob();
      await PaymentService.instance.simulate(
        jobId: jobId,
        amount: 150,
        method: 'card',
        forceFailure: true,
      );
      final retry = await PaymentService.instance.simulate(
        jobId: jobId,
        amount: 150,
        method: 'card',
      );
      expect(retry.status, PaymentStatus.success);
      expect(JobService.instance.jobById(jobId)!.paid, isTrue);
    });

    test('rejects a non-positive amount', () async {
      final jobId = await completedJob();
      expect(
        () => PaymentService.instance.simulate(
          jobId: jobId,
          amount: 0,
          method: 'cash',
        ),
        throwsArgumentError,
      );
    });

    test('a customer cannot pay before the job is completed', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.electrician,
      );
      // Still just "assigned" — nowhere near completed.
      expect(
        () => PaymentService.instance.simulate(
          jobId: job.jobId,
          amount: 100,
          method: 'upi',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a suspended customer cannot make a payment', () async {
      final jobId = await completedJob();
      AccountService.instance.cacheStatus('c1', AccountStatus.suspended);
      expect(
        () => PaymentService.instance.simulate(
          jobId: jobId,
          amount: 150,
          method: 'upi',
        ),
        throwsA(isA<AccountRestrictedException>()),
      );
    });
  });
}
