import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../../features/service_lifecycle/models/job_model.dart';
import '../../../features/service_lifecycle/widgets/job_status_ui.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_ticket_job_service.dart';

class AdminJobDetailScreen extends StatefulWidget {
  final String jobId;
  const AdminJobDetailScreen({super.key, required this.jobId});

  @override
  State<AdminJobDetailScreen> createState() => _AdminJobDetailScreenState();
}

class _AdminJobDetailScreenState extends State<AdminJobDetailScreen> {
  late Future<Job?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => _future = AdminTicketJobService.instance.fetchJob(widget.jobId);

  Future<void> _forceCancel(Job job) async {
    final reason = await showAdminReasonDialog(
      context,
      title: 'Force-cancel job',
      label: 'Reason (recorded in the audit log)',
    );
    if (reason == null) return;
    setState(() => _busy = true);
    await AdminTicketJobService.instance.forceCancelJob(job, reason: reason);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.jobId.isEmpty) {
      return const Scaffold(
        body: AdminEmptyView(
          title: 'No job selected',
          message: 'Open this screen from the Jobs list.',
        ),
      );
    }
    return FutureBuilder<Job?>(
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
        final job = snapshot.data;
        if (job == null) {
          return const Scaffold(
            body: AdminEmptyView(
              title: 'Job not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        return AdminPageScaffold(
          title: 'Job ${job.jobId}',
          subtitle:
              '${ServiceCategoryUi.label(job.category)} · ${job.customerName} → ${job.providerName}',
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
            if (job.isActive)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                ),
                onPressed: _busy ? null : () => _forceCancel(job),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Force-cancel'),
              ),
            IconButton(
              tooltip: 'Open ticket',
              onPressed: () => Navigator.of(context).pushNamed(
                AdminRouteNames.ticketDetail,
                arguments: job.ticketId,
              ),
              icon: const Icon(Icons.confirmation_number_outlined),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AdminStatusChip(
                    label: JobStatusUi.label(job.status),
                    color: JobStatusUi.color(job.status),
                  ),
                  if (job.hasOpenReport)
                    AdminStatusChip.semantic(
                      'Open report',
                      tone: AdminTone.warning,
                    ),
                  if (job.hasSafetyAlert)
                    AdminStatusChip.semantic(
                      'Safety alert',
                      tone: AdminTone.bad,
                    ),
                  if (job.paid)
                    AdminStatusChip.semantic('Paid', tone: AdminTone.good),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Section(
                      title: 'Customer',
                      rows: [
                        _row('Name', job.customerName),
                        _row('Phone', job.customerPhone ?? '—'),
                        _row('Rated provider', job.customerRated ? 'Yes' : 'No'),
                      ],
                      onTap: () => Navigator.of(context).pushNamed(
                        AdminRouteNames.userDetail,
                        arguments: job.customerId,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: _Section(
                      title: 'Provider',
                      rows: [
                        _row('Name', job.providerName),
                        _row('Phone', job.providerPhone ?? '—'),
                        _row('Rated customer', job.providerRated ? 'Yes' : 'No'),
                      ],
                      onTap: () => Navigator.of(context).pushNamed(
                        AdminRouteNames.userDetail,
                        arguments: job.providerId,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Timeline',
                rows: [
                  _row('Created', RelativeTime.format(job.createdAt)),
                  if (job.acceptedAt != null)
                    _row('Accepted', RelativeTime.format(job.acceptedAt!)),
                  if (job.enRouteAt != null)
                    _row('En route', RelativeTime.format(job.enRouteAt!)),
                  if (job.arrivedAt != null)
                    _row('Arrived', RelativeTime.format(job.arrivedAt!)),
                  if (job.completedAt != null)
                    _row('Completed', RelativeTime.format(job.completedAt!)),
                  if (job.closedAt != null)
                    _row('Closed', RelativeTime.format(job.closedAt!)),
                  if (job.cancellationReason != null)
                    _row('Cancellation reason', job.cancellationReason!),
                ],
              ),
              if (job.estimate != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _Section(
                  title: 'Estimate',
                  rows: [
                    _row('Diagnosis', job.estimate!.diagnosis),
                    _row('Labor', '₹${job.estimate!.laborCharge.toStringAsFixed(0)}'),
                    _row('Parts', '₹${job.estimate!.partsCharge.toStringAsFixed(0)}'),
                    _row('Total', '₹${job.estimate!.total.toStringAsFixed(0)}'),
                    if (job.estimate!.notes.isNotEmpty)
                      _row('Notes', job.estimate!.notes),
                    if (job.estimateRejectionReason != null)
                      _row('Rejected because', job.estimateRejectionReason!),
                  ],
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
  final VoidCallback? onTap;
  const _Section({required this.title, required this.rows, this.onTap});

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
              if (onTap != null)
                const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textHint),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...rows,
        ],
      ),
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: content,
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
            width: 140,
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
