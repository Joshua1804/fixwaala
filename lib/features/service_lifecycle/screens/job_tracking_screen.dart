import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/services/auth_service.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';

/// Central live-status hub for the customer's confirmed job.
///
/// Drives the rest of the customer workflow: depending on the job's current
/// [JobStatus], a contextual call-to-action routes the customer to the
/// Estimate Review, Completion Confirmation, Payment, or Rating screen.
class JobTrackingScreen extends StatelessWidget {
  final String? jobId;
  const JobTrackingScreen({super.key, this.jobId});

  @override
  Widget build(BuildContext context) {
    final argJobId =
        jobId ?? ModalRoute.of(context)?.settings.arguments as String?;

    if (argJobId != null) {
      return _JobTrackingBody(jobId: argJobId);
    }

    // No jobId supplied — resolve the customer's current active job.
    return Scaffold(
      appBar: AppBar(title: const Text('Job status')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget(label: 'Loading your job...');
          }
          final customerId = snapshot.data?.id;
          final job = customerId == null
              ? null
              : JobService.instance.activeJobForCustomer(customerId);
          if (job == null) {
            return const _NoActiveJobEmptyState();
          }
          return _JobTrackingBody(jobId: job.jobId);
        },
      ),
    );
  }
}

class _NoActiveJobEmptyState extends StatelessWidget {
  const _NoActiveJobEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.assignment_late_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No active job right now',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Once a provider confirms your request, you can track them here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobTrackingBody extends StatelessWidget {
  final String jobId;
  const _JobTrackingBody({required this.jobId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job status')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job status...');
          }
          final job = snapshot.data!;
          return _JobTrackingContent(job: job);
        },
      ),
    );
  }
}

class _JobTrackingContent extends StatelessWidget {
  final Job job;
  const _JobTrackingContent({required this.job});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _ProviderCard(job: job),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: JobStatusUi.color(job.status).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                JobStatusUi.icon(job.status),
                color: JobStatusUi.color(job.status),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  JobStatusUi.customerMessage(job.status),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: JobStatusUi.color(job.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('Progress', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        JobStatusStepper(current: job.status),
        const SizedBox(height: 8),
        _ContextualAction(job: job),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: job.isActive
                    ? () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.sos, arguments: job.jobId)
                    : null,
                icon: const Icon(Icons.emergency, color: AppColors.error),
                label: const Text('SOS'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  RouteNames.report,
                  arguments: {
                    'jobId': job.jobId,
                    'againstUserId': job.providerId,
                  },
                ),
                icon: const Icon(Icons.report_outlined),
                label: const Text('Report'),
              ),
            ),
          ],
        ),
        if (job.hasOpenReport) ...[
          const SizedBox(height: 12),
          StatusBadge.warning('Your report is under review'),
        ],
      ],
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final Job job;
  const _ProviderCard({required this.job});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(radius: 26, child: Icon(Icons.person)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.providerName, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    _categoryLabel(job.category),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: JobStatusUi.label(job.status),
              color: JobStatusUi.color(job.status),
              icon: JobStatusUi.icon(job.status),
            ),
          ],
        ),
      ),
    );
  }

  String _categoryLabel(ServiceCategory c) => switch (c) {
    ServiceCategory.plumber => 'Plumbing',
    ServiceCategory.electrician => 'Electrical',
    ServiceCategory.carpenter => 'Carpentry',
    ServiceCategory.unknown => 'Other',
  };
}

/// The single primary button the customer needs at this moment, if any.
class _ContextualAction extends StatelessWidget {
  final Job job;
  const _ContextualAction({required this.job});

  @override
  Widget build(BuildContext context) {
    switch (job.status) {
      case JobStatus.estimateSubmitted:
        return PrimaryButton(
          label: 'Review estimate',
          icon: Icons.receipt_long_rounded,
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(RouteNames.estimate, arguments: job.jobId),
        );
      case JobStatus.completionRequested:
        return PrimaryButton(
          label: 'Confirm completion',
          icon: Icons.task_alt_rounded,
          onPressed: () => Navigator.of(
            context,
          ).pushNamed(RouteNames.completion, arguments: job.jobId),
        );
      case JobStatus.completed:
        if (!job.paid) {
          return PrimaryButton(
            label: 'Make payment',
            icon: Icons.payment_rounded,
            onPressed: () => Navigator.of(
              context,
            ).pushNamed(RouteNames.payment, arguments: job.jobId),
          );
        }
        if (!job.customerRated) {
          return PrimaryButton(
            label: 'Rate your provider',
            icon: Icons.star_rounded,
            onPressed: () => Navigator.of(context).pushNamed(
              RouteNames.rating,
              arguments: {
                'jobId': job.jobId,
                'toUserId': job.providerId,
                'toName': job.providerName,
                'direction': RatingDirection.customerToProvider,
              },
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success),
              const SizedBox(width: 10),
              Text(
                'Job closed — thanks for using Fixwaala!',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      case JobStatus.cancelled:
        return const SizedBox.shrink();
      default:
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.divider.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text(
                'Waiting on your provider...',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
        );
    }
  }
}
