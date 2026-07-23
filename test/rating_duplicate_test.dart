import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/admin_panel/services/account_service.dart';
import 'package:fixwaala/features/payment/services/payment_service.dart';
import 'package:fixwaala/features/ratings/services/rating_service.dart';
import 'package:fixwaala/features/service_lifecycle/models/job_model.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
    RatingService.instance.resetForTesting();
    PaymentService.instance.resetForTesting();
    AccountService.instance.resetForTesting();
  });

  /// Drives a fresh job all the way to paid, since a rating is only valid
  /// once payment has gone through.
  Future<String> paidJob({
    String providerId = 'p1',
    String customerId = 'c1',
  }) async {
    final job = await JobService.instance.createJob(
      ticketId: 't1',
      providerId: providerId,
      providerName: 'Provider',
      customerId: customerId,
      customerName: 'Customer',
      category: ServiceCategory.carpenter,
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
        laborCharge: 50,
        partsCharge: 50,
        submittedAt: DateTime.now(),
      ),
    );
    await JobService.instance.approveEstimate(job.jobId);
    await JobService.instance.requestCompletion(job.jobId);
    await JobService.instance.confirmCompletion(job.jobId);
    await PaymentService.instance.simulate(
      jobId: job.jobId,
      amount: 100,
      method: 'upi',
    );
    return job.jobId;
  }

  group('Duplicate rating prevention', () {
    test('a customer can rate a completed, paid job once', () async {
      final jobId = await paidJob();
      final rating = await RatingService.instance.submit(
        jobId: jobId,
        fromUserId: 'c1',
        toUserId: 'p1',
        direction: RatingDirection.customerToProvider,
        stars: 5,
      );
      expect(rating.stars, 5);
      expect(
        RatingService.instance.hasRated(jobId: jobId, fromUserId: 'c1'),
        isTrue,
      );
    });

    test(
      'a second rating for the same job by the same user is rejected',
      () async {
        final jobId = await paidJob();
        await RatingService.instance.submit(
          jobId: jobId,
          fromUserId: 'c1',
          toUserId: 'p1',
          direction: RatingDirection.customerToProvider,
          stars: 4,
        );

        expect(
          () => RatingService.instance.submit(
            jobId: jobId,
            fromUserId: 'c1',
            toUserId: 'p1',
            direction: RatingDirection.customerToProvider,
            stars: 2,
          ),
          throwsA(isA<DuplicateRatingException>()),
        );
      },
    );

    test('a different user can still rate the same job', () async {
      final jobId = await paidJob();
      await RatingService.instance.submit(
        jobId: jobId,
        fromUserId: 'c1',
        toUserId: 'p1',
        direction: RatingDirection.customerToProvider,
        stars: 4,
      );
      final providerRating = await RatingService.instance.submit(
        jobId: jobId,
        fromUserId: 'p1',
        toUserId: 'c1',
        direction: RatingDirection.providerToCustomer,
        stars: 5,
      );
      expect(providerRating.stars, 5);
    });

    test('star rating must be between 1 and 5', () async {
      final jobId = await paidJob();
      expect(
        () => RatingService.instance.submit(
          jobId: jobId,
          fromUserId: 'c1',
          toUserId: 'p1',
          direction: RatingDirection.customerToProvider,
          stars: 0,
        ),
        throwsArgumentError,
      );
    });

    test('cannot rate a job that has not been paid yet', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.carpenter,
      );
      // Job is still just "assigned" — nowhere near paid.
      expect(
        () => RatingService.instance.submit(
          jobId: job.jobId,
          fromUserId: 'c1',
          toUserId: 'p1',
          direction: RatingDirection.customerToProvider,
          stars: 5,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a suspended user cannot submit a rating', () async {
      final jobId = await paidJob();
      await AccountService.instance.suspend('c1', reason: 'test');
      expect(
        () => RatingService.instance.submit(
          jobId: jobId,
          fromUserId: 'c1',
          toUserId: 'p1',
          direction: RatingDirection.customerToProvider,
          stars: 5,
        ),
        throwsA(isA<AccountRestrictedException>()),
      );
    });
  });
}
