import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/payment/models/payment_model.dart';
import '../../core/admin_auth_service.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'admin_payment_list_screen.dart';
import 'services/admin_payment_service.dart';

class AdminPaymentDetailScreen extends StatefulWidget {
  final String paymentId;
  const AdminPaymentDetailScreen({super.key, required this.paymentId});

  @override
  State<AdminPaymentDetailScreen> createState() =>
      _AdminPaymentDetailScreenState();
}

class _AdminPaymentDetailScreenState extends State<AdminPaymentDetailScreen> {
  late Future<PaymentRecord?> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() =>
      _future = AdminPaymentService.instance.fetchOne(widget.paymentId);

  Future<void> _resolveDispute(
    PaymentRecord payment,
    PaymentDisputeStatus status,
  ) async {
    final noteController = TextEditingController(
      text: payment.disputeNote ?? '',
    );
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set dispute status: ${disputeStatusLabel(status)}'),
        content: TextField(
          controller: noteController,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Note'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(noteController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (note == null) return;
    setState(() => _busy = true);
    try {
      await AdminPaymentService.instance.setDispute(
        payment,
        status: status,
        note: note,
        adminId: AdminAuthService.instance.currentUid ?? 'unknown',
      );
      if (mounted) setState(_load);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.paymentId.isEmpty) {
      return const Scaffold(
        body: AdminEmptyView(
          title: 'No payment selected',
          message: 'Open this screen from the Payments list.',
        ),
      );
    }
    return FutureBuilder<PaymentRecord?>(
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
        final payment = snapshot.data;
        if (payment == null) {
          return const Scaffold(
            body: AdminEmptyView(
              title: 'Payment not found',
              message: 'It may have been deleted.',
            ),
          );
        }
        return AdminPageScaffold(
          title: 'Payment ${payment.id}',
          subtitle:
              '₹${payment.amount.toStringAsFixed(0)} via ${payment.method}',
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
            IconButton(
              tooltip: 'Open job',
              onPressed: () => Navigator.of(
                context,
              ).pushNamed(AdminRouteNames.jobDetail, arguments: payment.jobId),
              icon: const Icon(Icons.work_outline_rounded),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  AdminStatusChip.semantic(
                    paymentStatusLabel(payment.status),
                    tone: paymentStatusTone(payment.status),
                  ),
                  AdminStatusChip.semantic(
                    disputeStatusLabel(payment.disputeStatus),
                    tone: disputeStatusTone(payment.disputeStatus),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              _Section(
                title: 'Payment',
                rows: [
                  _row('Amount', '₹${payment.amount.toStringAsFixed(2)}'),
                  _row('Method', payment.method),
                  _row('Status', paymentStatusLabel(payment.status)),
                  if (payment.failureReason != null)
                    _row('Failure reason', payment.failureReason!),
                  _row('Processed', RelativeTime.format(payment.processedAt)),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Parties',
                rows: [
                  Row(
                    children: [
                      Expanded(child: _row('Customer', payment.customerId)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AdminRouteNames.userDetail,
                          arguments: payment.customerId,
                        ),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(child: _row('Provider', payment.providerId)),
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AdminRouteNames.userDetail,
                          arguments: payment.providerId,
                        ),
                        child: const Text('View'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: 'Dispute',
                rows: [
                  _row('Status', disputeStatusLabel(payment.disputeStatus)),
                  if (payment.disputeNote != null)
                    _row('Note', payment.disputeNote!),
                  if (payment.disputeUpdatedAt != null)
                    _row(
                      'Last updated',
                      RelativeTime.format(payment.disputeUpdatedAt!),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    children: [
                      if (payment.disputeStatus == PaymentDisputeStatus.none)
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _resolveDispute(
                                  payment,
                                  PaymentDisputeStatus.disputed,
                                ),
                          child: const Text('Open dispute'),
                        ),
                      if (payment.disputeStatus ==
                          PaymentDisputeStatus.disputed) ...[
                        OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () => _resolveDispute(
                                  payment,
                                  PaymentDisputeStatus.resolved,
                                ),
                          child: const Text('Mark resolved'),
                        ),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.warning,
                            side: const BorderSide(color: AppColors.warning),
                          ),
                          onPressed: _busy
                              ? null
                              : () => _resolveDispute(
                                  payment,
                                  PaymentDisputeStatus.refunded,
                                ),
                          child: const Text('Mark refunded'),
                        ),
                      ],
                      if (payment.disputeStatus != PaymentDisputeStatus.none)
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _resolveDispute(
                                  payment,
                                  PaymentDisputeStatus.none,
                                ),
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) =>
      _DetailRow(label: label, value: value);
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
