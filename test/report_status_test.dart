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

    test('a report tied to a job flags it for admin visibility', () async {
      final job = await JobService.instance.createJob(
        ticketId: 't1',
        providerId: 'p1',
        providerName: 'Provider',
        customerId: 'c1',
        customerName: 'Customer',
        category: ServiceCategory.plumber,
      );
      await ReportService.instance.submitReport(
        reporterId: 'c1',
        reason: 'Payment issue',
        description: 'Overcharged',
        severity: ReportSeverity.low,
        jobId: job.jobId,
      );
      expect(JobService.instance.jobById(job.jobId)!.hasOpenReport, isTrue);
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
  });
}
