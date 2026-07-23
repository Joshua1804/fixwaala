import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';

/// Provider's Status Update Screen.
///
/// Shows the full lifecycle stepper with the current step highlighted and a
/// single primary action that advances the job — or, for [JobStatus.assigned]
/// and [JobStatus.inspecting], the appropriate branch (accept/reject, or
/// hand off to the Inspection & Estimate Screen for data entry).
class StatusUpdateScreen extends StatelessWidget {
  final String? jobId;
  const StatusUpdateScreen({super.key, this.jobId});

  String _resolveJobId(BuildContext context) =>
      jobId ?? ModalRoute.of(context)!.settings.arguments as String;

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _rejectJob(BuildContext context, String id) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this job?'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'Reason (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    await _run(
      context,
      () => JobService.instance.providerReject(
        id,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      ),
    );
    if (context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final id = _resolveJobId(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Update status')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job...');
          }
          final job = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Current status', style: AppTextStyles.titleLarge),
                const SizedBox(height: 4),
                Text(
                  JobStatusUi.label(job.status),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: JobStatusUi.color(job.status),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: JobStatusStepper(current: job.status),
                  ),
                ),
                _ActionRow(
                  job: job,
                  onReject: () => _rejectJob(context, id),
                  run: (f) => _run(context, f),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final Job job;
  final VoidCallback onReject;
  final void Function(Future<void> Function()) run;

  const _ActionRow({
    required this.job,
    required this.onReject,
    required this.run,
  });

  @override
  Widget build(BuildContext context) {
    switch (job.status) {
      case JobStatus.assigned:
        return Column(
          children: [
            PrimaryButton(
              label: 'Accept job',
              onPressed: () =>
                  run(() => JobService.instance.providerAccept(job.jobId)),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onReject,
              child: const Text('Reject job'),
            ),
          ],
        );
      case JobStatus.accepted:
        return PrimaryButton(
          label: 'Start travel (En Route)',
          onPressed: () =>
              run(() => JobService.instance.startEnRoute(job.jobId)),
        );
      case JobStatus.enRoute:
        return PrimaryButton(
          label: 'Mark arrived',
          onPressed: () =>
              run(() => JobService.instance.markArrived(job.jobId)),
        );
      case JobStatus.arrived:
        return PrimaryButton(
          label: 'Check in',
          onPressed: () => run(() => JobService.instance.checkIn(job.jobId)),
        );
      case JobStatus.checkedIn:
        return PrimaryButton(
          label: 'Start inspection',
          onPressed: () =>
              run(() => JobService.instance.startInspection(job.jobId)),
        );
      case JobStatus.inspecting:
        return PrimaryButton(
          label: 'Enter diagnosis & estimate',
          icon: Icons.receipt_long_rounded,
          onPressed: () => Navigator.of(context).pushNamed(
            RouteNames.providerInspectionEstimate,
            arguments: job.jobId,
          ),
        );
      case JobStatus.workInProgress:
        return PrimaryButton(
          label: 'Request completion',
          onPressed: () =>
              run(() => JobService.instance.requestCompletion(job.jobId)),
        );
      case JobStatus.estimateSubmitted:
        return const _WaitingBanner(
          text: 'Waiting for the customer to review the estimate.',
        );
      case JobStatus.completionRequested:
        return const _WaitingBanner(
          text: 'Waiting for the customer to confirm completion.',
        );
      case JobStatus.completed:
      case JobStatus.cancelled:
        return const SizedBox.shrink();
    }
  }
}

class _WaitingBanner extends StatelessWidget {
  final String text;
  const _WaitingBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top_rounded, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppColors.warning)),
          ),
        ],
      ),
    );
  }
}
