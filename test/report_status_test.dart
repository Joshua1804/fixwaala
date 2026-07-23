import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/features/reports_safety/services/report_service.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
    ReportService.instance.resetForTesting();
  });

  group('Report status transitions', () {
    test('a new report starts as open', () async {
      final report = await ReportService.instance.submitReport(
        reporterId: 'c1',
        reason: 'Provider misbehaved',
        description: 'Was late and rude',
        severity: ReportSeverity.medium,
      );
      expect(report.status, ReportStatus.open);
      expect(
        ReportService.instance.openReports().map((r) => r.id),
        contains(report.id),
      );
    });

    test('an admin can move a report through review to resolved', () async {
      final report = await ReportService.instance.submitReport(
        reporterId: 'c1',
        reason: 'Poor quality of work',
        description: 'Leak was not fixed',
        severity: ReportSeverity.high,
      );

      await ReportService.instance.updateReportStatus(
        report.id,
        ReportStatus.underReview,
        adminId: 'admin1',
      );
      expect(
        ReportService.instance
            .allReports()
            .firstWhere((r) => r.id == report.id)
            .status,
        ReportStatus.underReview,
      );

      await ReportService.instance.updateReportStatus(
        report.id,
        ReportStatus.resolved,
        adminId: 'admin1',
        note: 'Refunded customer',
      );
      final resolved = ReportService.instance.allReports().firstWhere(
        (r) => r.id == report.id,
      );
      expect(resolved.status, ReportStatus.resolved);
      expect(resolved.resolvedByAdminId, 'admin1');
      expect(resolved.adminNote, 'Refunded customer');
      expect(
        ReportService.instance.openReports().map((r) => r.id),
        isNot(contains(report.id)),
      );
    });

    test(
      'a report tied to a job flags it, and clearing it lifts the flag',
      () async {
        final job = await JobService.instance.createJob(
          ticketId: 't1',
          providerId: 'p1',
          providerName: 'Provider',
          customerId: 'c1',
          customerName: 'Customer',
          category: ServiceCategory.plumber,
        );
        final report = await ReportService.instance.submitReport(
          reporterId: 'c1',
          reason: 'Payment issue',
          description: 'Overcharged',
          severity: ReportSeverity.low,
          jobId: job.jobId,
        );
        expect(JobService.instance.jobById(job.jobId)!.hasOpenReport, isTrue);

        await ReportService.instance.updateReportStatus(
          report.id,
          ReportStatus.rejected,
          adminId: 'admin1',
        );
        expect(JobService.instance.jobById(job.jobId)!.hasOpenReport, isFalse);
      },
    );

    test('updating an unknown report throws', () {
      expect(
        () => ReportService.instance.updateReportStatus(
          'missing',
          ReportStatus.resolved,
        ),
        throwsArgumentError,
      );
    });
  });

  group('SOS alert creation', () {
    test('raising an SOS creates an unresolved safety alert', () async {
      final alert = await ReportService.instance.raiseSos(userId: 'c1');
      expect(alert.resolved, isFalse);
      expect(
        ReportService.instance.unresolvedSafetyAlerts().map((a) => a.id),
        contains(alert.id),
      );
    });

    test('an SOS tied to a job flags the job for admin visibility', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
      );
      await ReportService.instance.raiseSos(userId: 'c1', jobId: job.jobId);
      expect(JobService.instance.jobById(job.jobId)!.hasSafetyAlert, isTrue);
    });

    test('an admin can resolve a safety alert', () async {
      final alert = await ReportService.instance.raiseSos(userId: 'c1');
      await ReportService.instance.resolveSafetyAlert(
        alert.id,
        adminId: 'admin1',
      );
      final resolved = ReportService.instance.allSafetyAlerts().firstWhere(
        (a) => a.id == alert.id,
      );
      expect(resolved.resolved, isTrue);
      expect(resolved.resolvedByAdminId, 'admin1');
      expect(
        ReportService.instance.unresolvedSafetyAlerts().map((a) => a.id),
        isNot(contains(alert.id)),
      );
    });

    test('resolving an unknown safety alert throws', () {
      expect(
        () => ReportService.instance.resolveSafetyAlert(
          'missing',
          adminId: 'admin1',
        ),
        throwsArgumentError,
      );
    });
  });
}
