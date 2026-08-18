import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../core/widgets/status_badge.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../../payment/services/payment_service.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../widgets/job_status_ui.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';
import '../../../core/widgets/contact_party_button.dart';
import '../../../core/widgets/mid_job_checkpoint.dart';

/// Provider's Job Details Screen — full context on a single job plus a
/// link into the Status Update Screen for the next lifecycle action.
class JobDetailsScreen extends StatelessWidget {
  final String? jobId;
  const JobDetailsScreen({super.key, this.jobId});

  /// Empty when this route was opened without a job id — [build] guards on
  /// it and shows a real message. This used to be
  /// `ModalRoute.of(context)!.settings.arguments as String`, which threw on
  /// both the `!` and the cast, so arriving here from a notification tap or a
  /// restored navigation stack crashed the screen.
  String _resolveJobId(BuildContext context) =>
      jobId ?? ModalRoute.of(context)?.settings.arguments as String? ?? '';

  @override
  Widget build(BuildContext context) {
    final id = _resolveJobId(context);
    if (id.isEmpty) {
      return const MissingRouteArgumentScreen(title: 'Job details');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Job details')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job...');
          }
          final job = snapshot.data!;
          MidJobCheckpoint.maybeShow(
            context,
            jobId: job.jobId,
            status: job.status,
            otherPartyId: job.customerId,
          );
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
                                const SizedBox(height: 8),
                                ContactPartyButton(
                                  phoneNumber: job.customerPhone,
                                  partyLabel: 'customer',
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
              StreamBuilder<Ticket>(
                stream: TicketService.instance.watchTicket(job.ticketId),
                builder: (context, ticketSnapshot) {
                  final ticket = ticketSnapshot.data;
                  if (ticket == null) return const SizedBox.shrink();
                  final hasSummary = (ticket.aiSummary ?? '').isNotEmpty;
                  final hasEquipment = ticket.recommendedEquipment.isNotEmpty;
                  final hasQa = ticket.clarifyingQa.isNotEmpty;
                  final hasPhotos = ticket.imageUrls.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Problem details',
                              style: AppTextStyles.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(ticket.description),
                            if (hasPhotos) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 72,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: ticket.imageUrls.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, i) => RemoteImage(
                                    url: ticket.imageUrls[i],
                                    width: 72,
                                    height: 72,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                            if (hasSummary) ...[
                              const SizedBox(height: 12),
                              Text('Summary', style: AppTextStyles.titleMedium),
                              const SizedBox(height: 4),
                              Text(ticket.aiSummary!),
                            ],
                            if (hasEquipment) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Bring with you',
                                style: AppTextStyles.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: ticket.recommendedEquipment
                                    .map((e) => Chip(label: Text(e)))
                                    .toList(),
                              ),
                            ],
                            if (hasQa) ...[
                              const SizedBox(height: 12),
                              ExpansionTile(
                                tilePadding: EdgeInsets.zero,
                                title: const Text('Follow-up answers'),
                                children: ticket.clarifyingQa
                                    .map(
                                      (qa) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              qa.question,
                                              style: AppTextStyles.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            ),
                                            Text(qa.answer),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
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
