import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/service_lifecycle/models/job_model.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
  });

  Future<String> createDemoJob() async {
    final job = await JobService.instance.createJob(
      ticketId: 't1',
      providerId: 'p1',
      providerName: 'Provider One',
      customerId: 'c1',
      customerName: 'Customer One',
      category: ServiceCategory.plumber,
    );
    return job.jobId;
  }

  group('Job lifecycle transitions', () {
    test('a new job starts as assigned', () async {
      final id = await createDemoJob();
      expect(JobService.instance.jobById(id)!.status, JobStatus.assigned);
    });

    test('the full happy path advances status step by step', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.accepted);

      await JobService.instance.startEnRoute(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.enRoute);

      await JobService.instance.markArrived(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.arrived);

      await JobService.instance.checkIn(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.checkedIn);

      await JobService.instance.startInspection(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.inspecting);

      await JobService.instance.submitEstimate(
        id,
        RepairEstimate(
          diagnosis: 'Leaky pipe',
          laborCharge: 200,
          partsCharge: 100,
          submittedAt: DateTime.now(),
        ),
      );
      expect(
        JobService.instance.jobById(id)!.status,
        JobStatus.estimateSubmitted,
      );

      await JobService.instance.approveEstimate(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.workInProgress);

      await JobService.instance.requestCompletion(id);
      expect(
        JobService.instance.jobById(id)!.status,
        JobStatus.completionRequested,
      );

      await JobService.instance.confirmCompletion(id);
      expect(JobService.instance.jobById(id)!.status, JobStatus.completed);
      expect(JobService.instance.jobById(id)!.completedAt, isNotNull);
    });

    test('rejecting an estimate cancels the job', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      await JobService.instance.startEnRoute(id);
      await JobService.instance.markArrived(id);
      await JobService.instance.checkIn(id);
      await JobService.instance.startInspection(id);
      await JobService.instance.submitEstimate(
        id,
        RepairEstimate(
          diagnosis: 'Diagnosis',
          laborCharge: 50,
          partsCharge: 50,
          submittedAt: DateTime.now(),
        ),
      );
      await JobService.instance.rejectEstimate(id, reason: 'Too expensive');
      final job = JobService.instance.jobById(id)!;
      expect(job.status, JobStatus.cancelled);
      expect(job.estimateRejectionReason, 'Too expensive');
      expect(job.isTerminal, isTrue);
    });

    test(
      'a cancelled job disappears from active/completed but stays visible in history',
      () async {
        final id = await createDemoJob();
        await JobService.instance.providerAccept(id);
        await JobService.instance.startEnRoute(id);
        await JobService.instance.markArrived(id);
        await JobService.instance.checkIn(id);
        await JobService.instance.startInspection(id);
        await JobService.instance.submitEstimate(
          id,
          RepairEstimate(
            diagnosis: 'x',
            laborCharge: 10,
            partsCharge: 10,
            submittedAt: DateTime.now(),
          ),
        );
        await JobService.instance.rejectEstimate(id, reason: 'no thanks');

        expect(
          JobService.instance.activeJobsForProvider('p1').map((j) => j.jobId),
          isNot(contains(id)),
        );
        expect(
          JobService.instance
              .completedJobsForProvider('p1')
              .map((j) => j.jobId),
          isNot(contains(id)),
        );
        expect(
          JobService.instance.historyJobsForProvider('p1').map((j) => j.jobId),
          contains(id),
        );
      },
    );

    test('cannot skip states — e.g. cannot check in before arriving', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      expect(
        () => JobService.instance.checkIn(id),
        throwsA(isA<JobTransitionException>()),
      );
    });

    test('cannot submit an estimate before inspection has started', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      await JobService.instance.startEnRoute(id);
      await JobService.instance.markArrived(id);
      await JobService.instance.checkIn(id);
      expect(
        () => JobService.instance.submitEstimate(
          id,
          RepairEstimate(
            diagnosis: 'x',
            laborCharge: 1,
            partsCharge: 1,
            submittedAt: DateTime.now(),
          ),
        ),
        throwsA(isA<JobTransitionException>()),
      );
    });

    test('cannot re-cancel an already completed job', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      await JobService.instance.startEnRoute(id);
      await JobService.instance.markArrived(id);
      await JobService.instance.checkIn(id);
      await JobService.instance.startInspection(id);
      await JobService.instance.submitEstimate(
        id,
        RepairEstimate(
          diagnosis: 'x',
          laborCharge: 1,
          partsCharge: 1,
          submittedAt: DateTime.now(),
        ),
      );
      await JobService.instance.approveEstimate(id);
      await JobService.instance.requestCompletion(id);
      await JobService.instance.confirmCompletion(id);

      expect(
        () => JobService.instance.cancelJob(id),
        throwsA(isA<JobTransitionException>()),
      );
    });

    test('provider can only reject a job while it is newly assigned', () async {
      final id = await createDemoJob();
      await JobService.instance.providerAccept(id);
      expect(
        () => JobService.instance.providerReject(id),
        throwsA(isA<JobTransitionException>()),
      );
    });
  });
}
