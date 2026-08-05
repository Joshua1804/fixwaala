import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../features/customer_ticket/models/ticket_model.dart';
import '../../../features/customer_ticket/widgets/ticket_status_ui.dart';
import '../../../features/service_lifecycle/models/job_model.dart';
import '../../../features/service_lifecycle/widgets/job_status_ui.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_ticket_job_service.dart';

class AdminTicketDetailScreen extends StatefulWidget {
  final String ticketId;
  const AdminTicketDetailScreen({super.key, required this.ticketId});

  @override
  State<AdminTicketDetailScreen> createState() =>
      _AdminTicketDetailScreenState();
}

class _AdminTicketDetailScreenState extends State<AdminTicketDetailScreen> {
  late Future<(Ticket?, Job?)> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminTicketJobService.instance.fetchTicket(widget.ticketId).then((
      ticket,
    ) async {
      if (ticket == null) return (null, null);
      final job = await AdminTicketJobService.instance.fetchJobForTicket(
        ticket.id,
      );
      return (ticket, job);
    });
  }

  Future<void> _forceCancel(Ticket ticket) async {
    final reason = await showAdminReasonDialog(
      context,
      title: 'Force-cancel ticket',
      label: 'Reason (recorded in the audit log)',
    );
    if (reason == null) return;
    setState(() => _busy = true);
    await AdminTicketJobService.instance.forceCancelTicket(
      ticket,
      reason: reason,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ticketId.isEmpty) {
      return const Scaffold(
        body: AdminEmptyView(
          title: 'No ticket selected',
          message: 'Open this screen from the Tickets list.',
        ),
      );
    }
    return FutureBuilder<(Ticket?, Job?)>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: AdminLoadingView());
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: AdminErrorView(
              error: snapshot.error!,
              onRetry: () => setState(_load),
            ),
          );
        }
        final (ticket, job) = snapshot.data!;
        if (ticket == null) {
          return const Scaffold(
            body: AdminEmptyView(
              title: 'Ticket not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        final isTerminal = !ticket.isActive;
        return AdminPageScaffold(
          title: 'Ticket ${ticket.id}',
          subtitle: '${ServiceCategoryUi.label(ticket.category)} · '
              '${ticket.customerName.isNotEmpty ? ticket.customerName : ticket.customerFirstName}',
          actions: [
            if (_busy)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            if (!isTerminal)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _busy ? null : () => _forceCancel(ticket),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Force-cancel'),
              ),
            IconButton(
              tooltip: 'Open customer profile',
              onPressed: () => Navigator.of(context).pushNamed(
                AdminRouteNames.userDetail,
                arguments: ticket.customerId,
              ),
              icon: const Icon(Icons.person_outline_rounded),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AdminStatusChip(
                    label: TicketStatusUi.label(ticket.status),
                    color: TicketStatusUi.color(ticket.status),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Request',
                rows: [
                  _row('Description', ticket.description),
                  _row('Complexity', ticket.complexity.name),
                  _row('Created', RelativeTime.format(ticket.createdAt)),
                  if (ticket.updatedAt != null)
                    _row('Updated', RelativeTime.format(ticket.updatedAt!)),
                  _row('Broadcast radius', '${ticket.broadcastRadiusKm} km'),
                  if (ticket.addressLine != null)
                    _row('Address (private)', ticket.addressLine!),
                  if (ticket.aiSummary != null)
                    _row('AI summary', ticket.aiSummary!),
                  if (ticket.recommendedEquipment.isNotEmpty)
                    _row(
                      'Recommended equipment',
                      ticket.recommendedEquipment.join(', '),
                    ),
                ],
              ),
              if (ticket.imageUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Photos', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: ticket.imageUrls.map((url) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        width: 120,
                        height: 120,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 120,
                          height: 120,
                          color: AppColors.background,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (ticket.clarifyingQa.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Clarifying answers', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.divider.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: ticket.clarifyingQa
                        .map(
                          (qa) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  qa.question,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                Text(qa.answer, style: AppTextStyles.bodyMedium),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
              if (job != null) ...[
                const SizedBox(height: AppSpacing.xxl),
                Text('Job', style: AppTextStyles.titleMedium),
                const SizedBox(height: AppSpacing.md),
                Material(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).pushNamed(
                      AdminRouteNames.jobDetail,
                      arguments: job.jobId,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppColors.divider.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Job ${job.jobId}',
                                  style: AppTextStyles.titleSmall,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  job.providerName,
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AdminStatusChip(
                            label: JobStatusUi.label(job.status),
                            color: JobStatusUi.color(job.status),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.chevron_right_rounded, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) => _DetailRow(label: label, value: value);
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...rows,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Text(value, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}
