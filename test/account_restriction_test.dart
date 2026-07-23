import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/admin_panel/services/account_service.dart';
import 'package:fixwaala/features/admin_panel/services/admin_service.dart';
import 'package:fixwaala/features/service_lifecycle/models/job_model.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
    AccountService.instance.resetForTesting();
    AdminService.instance.resetForTesting();
  });

  group('Account restriction and suspension', () {
    test('a fresh account is active by default', () {
      expect(AccountService.instance.statusOf('u1'), AccountStatus.active);
      expect(() => AccountService.instance.assertActive('u1'), returnsNormally);
    });

    test('restricting an account blocks it and can be restored', () async {
      await AccountService.instance.restrict(
        'u1',
        reason: 'suspicious activity',
      );
      expect(AccountService.instance.statusOf('u1'), AccountStatus.restricted);
      expect(
        () => AccountService.instance.assertActive('u1'),
        throwsA(isA<AccountRestrictedException>()),
      );

      await AccountService.instance.restore('u1');
      expect(AccountService.instance.statusOf('u1'), AccountStatus.active);
      expect(() => AccountService.instance.assertActive('u1'), returnsNormally);
    });

    test('suspending an account blocks it and can be restored', () async {
      await AccountService.instance.suspend('u1', reason: 'policy violation');
      expect(AccountService.instance.statusOf('u1'), AccountStatus.suspended);
      expect(
        () => AccountService.instance.assertActive('u1'),
        throwsA(isA<AccountRestrictedException>()),
      );

      await AccountService.instance.restore('u1');
      expect(AccountService.instance.statusOf('u1'), AccountStatus.active);
    });
  });

  group('Role-based access restrictions on job actions', () {
    test('a suspended provider cannot accept a job', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
      );
      await AccountService.instance.suspend('p1', reason: 'test');
      expect(
        () => JobService.instance.providerAccept(job.jobId),
        throwsA(isA<AccountRestrictedException>()),
      );
    });

    test('a restricted provider cannot submit an estimate', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
      );
      await JobService.instance.providerAccept(job.jobId);
      await JobService.instance.startEnRoute(job.jobId);
      await JobService.instance.markArrived(job.jobId);
      await JobService.instance.checkIn(job.jobId);
      await JobService.instance.startInspection(job.jobId);
      await AccountService.instance.restrict('p1', reason: 'test');

      expect(
        () => JobService.instance.submitEstimate(
          job.jobId,
          RepairEstimate(
            diagnosis: 'x',
            laborCharge: 10,
            partsCharge: 10,
            submittedAt: DateTime.now(),
          ),
        ),
        throwsA(isA<AccountRestrictedException>()),
      );
    });

    test('a suspended customer cannot approve an estimate', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
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
          laborCharge: 10,
          partsCharge: 10,
          submittedAt: DateTime.now(),
        ),
      );
      await AccountService.instance.suspend('c1', reason: 'test');

      expect(
        () => JobService.instance.approveEstimate(job.jobId),
        throwsA(isA<AccountRestrictedException>()),
      );
    });

    test('restoring the account allows the action to proceed', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
      );
      await AccountService.instance.suspend('p1', reason: 'test');
      expect(
        () => JobService.instance.providerAccept(job.jobId),
        throwsA(isA<AccountRestrictedException>()),
      );

      await AccountService.instance.restore('p1');
      await JobService.instance.providerAccept(job.jobId);
      expect(
        JobService.instance.jobById(job.jobId)!.status,
        JobStatus.accepted,
      );
    });
  });

  group('Admin audit-event creation', () {
    test('restricting an account logs an audit event', () async {
      await AdminService.instance.restrictAccount(
        'u1',
        adminId: 'admin1',
        reason: 'spam reports',
      );
      final events = AdminService.instance.auditEvents();
      expect(events, hasLength(1));
      expect(events.first.action, 'restrictAccount');
      expect(events.first.actorAdminId, 'admin1');
      expect(events.first.targetId, 'u1');
      expect(events.first.payload['reason'], 'spam reports');
    });

    test('suspending and restoring both log separate audit events', () async {
      await AdminService.instance.suspendAccount(
        'u1',
        adminId: 'admin1',
        reason: 'policy violation',
      );
      await AdminService.instance.restoreAccount('u1', adminId: 'admin1');
      final events = AdminService.instance.auditEvents();
      expect(events, hasLength(2));
      expect(
        events.map((e) => e.action),
        containsAll(['suspendAccount', 'restoreAccount']),
      );
    });
  });
}
