import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../core/widgets/status_badge.dart';
import '../../payment/services/payment_service.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';

/// Provider's Job Details Screen — full context on a single job plus a
/// link into the Status Update Screen for the next lifecycle action.
class JobDetailsScreen extends StatelessWidget {
  final String? jobId;
  const JobDetailsScreen({super.key, this.jobId});

  String _resolveJobId(BuildContext context) =>
      jobId ?? ModalRoute.of(context)!.settings.arguments as String;

  @override
  Widget build(BuildContext context) {
    final id = _resolveJobId(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job...');
          }
          final job = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.person),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  job.customerName,
                                  style: AppTextStyles.titleMedium,
                                ),
                                Text(
                                  ServiceCategoryUi.label(job.category),
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
                          ),
                        ],
                      ),
                      if (job.hasSafetyAlert || job.hasOpenReport) ...[
                        const SizedBox(height: 12),
                        if (job.hasSafetyAlert)
                          StatusBadge.error('SOS raised on this job'),
                        if (job.hasOpenReport)
                          StatusBadge.warning('A report is open on this job'),
                      ],
                      if (job.status == JobStatus.cancelled) ...[
                        const SizedBox(height: 12),
                        Text(
                          job.estimateRejectionReason != null
                              ? 'Customer rejected the estimate'
                                    '${job.estimateRejectionReason!.isEmpty ? '' : ': ${job.estimateRejectionReason}'}'
                              : job.cancellationReason != null
                              ? 'Cancelled: ${job.cancellationReason}'
                              : 'This job was cancelled.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                      ],
                      if (job.status == JobStatus.completed) ...[
                        const SizedBox(height: 12),
                        Builder(
                          builder: (context) {
                            final payment = PaymentService.instance
                                .paymentForJob(job.jobId);
                            return job.paid
                                ? StatusBadge.success(
                                    'Paid${payment == null ? '' : ' — ₹${payment.amount.toStringAsFixed(0)}'}',
                                  )
                                : StatusBadge.warning('Awaiting payment');
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (job.estimate != null) ...[
                Text('Estimate', style: AppTextStyles.titleLarge),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(job.estimate!.diagnosis),
                        const SizedBox(height: 8),
                        Text(
                          'Total: ₹${job.estimate!.total.toStringAsFixed(0)}',
                          style: AppTextStyles.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text('Timeline', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              JobStatusStepper(current: job.status),
              const SizedBox(height: 12),
              if (job.status != JobStatus.cancelled &&
                  job.status != JobStatus.completed)
                PrimaryButton(
                  label: JobStatusUi.providerActionLabel(job.status) == null
                      ? 'Waiting on customer'
                      : 'Update status',
                  onPressed: JobStatusUi.providerActionLabel(job.status) == null
                      ? null
                      : () => Navigator.of(context).pushNamed(
                          RouteNames.providerStatusUpdate,
                          arguments: job.jobId,
                        ),
                ),
              if (job.status == JobStatus.completed &&
                  job.paid &&
                  !job.providerRated)
                PrimaryButton(
                  label: 'Rate customer',
                  icon: Icons.star_rounded,
                  onPressed: () => Navigator.of(context).pushNamed(
                    RouteNames.rating,
                    arguments: {
                      'jobId': job.jobId,
                      'toUserId': job.customerId,
                      'toName': job.customerName,
                      'direction': RatingDirection.providerToCustomer,
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
