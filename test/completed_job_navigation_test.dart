import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/routes/route_names.dart';
import 'package:fixwaala/features/service_lifecycle/models/job_model.dart';
import 'package:fixwaala/features/service_lifecycle/screens/status_update_screen.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';

void main() {
  setUp(() {
    JobService.instance.resetForTesting();
  });

  testWidgets('StatusUpdateScreen renders Job Details and Home Screen buttons when completed',
      (WidgetTester tester) async {
    final job = await JobService.instance.createJob(
      ticketId: 't1',
      providerId: 'p1',
      providerName: 'Provider One',
      customerId: 'c1',
      customerName: 'Customer One',
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
        diagnosis: 'Fixed pipe',
        laborCharge: 100,
        partsCharge: 50,
        submittedAt: DateTime.now(),
      ),
    );
    await JobService.instance.approveEstimate(job.jobId);
    await JobService.instance.requestCompletion(job.jobId);
    await JobService.instance.confirmCompletion(job.jobId);

    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: (settings) {
          if (settings.name == RouteNames.providerStatusUpdate) {
            return MaterialPageRoute(
              builder: (_) => StatusUpdateScreen(jobId: job.jobId),
            );
          }
          return MaterialPageRoute(
            builder: (_) => Scaffold(body: Text('Screen: ${settings.name}')),
          );
        },
        initialRoute: RouteNames.providerStatusUpdate,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Job Details'), findsOneWidget);
    expect(find.text('Home Screen'), findsOneWidget);

    // Tap Job Details
    await tester.tap(find.text('Job Details'));
    await tester.pumpAndSettle();
    expect(find.text('Screen: ${RouteNames.providerJobDetails}'), findsOneWidget);
  });
}
