import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';

/// Customer-facing Estimate Review Screen.
///
/// Shown once a provider has submitted a diagnosis + repair estimate. The
/// customer must accept (work proceeds) or reject (job is cancelled) before
/// any work begins.
class EstimateScreen extends StatefulWidget {
  final String? jobId;
  const EstimateScreen({super.key, this.jobId});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  bool _busy = false;

  /// Empty when this route was opened without a job id — [build] guards on
  /// it and shows a real message. This used to be
  /// `ModalRoute.of(context)!.settings.arguments as String`, which threw on
  /// both the `!` and the cast, so arriving here from a notification tap or a
  /// restored navigation stack crashed the screen.
  String get _jobId =>
      widget.jobId ??
      ModalRoute.of(context)?.settings.arguments as String? ??
      '';

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      await JobService.instance.approveEstimate(_jobId);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(RouteNames.jobTracking);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject this estimate?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The job will be cancelled and will not continue.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep estimate'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reject & cancel job'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      await JobService.instance.rejectEstimate(
        _jobId,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.customerHome, (route) => false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobId.isEmpty) {
      return const MissingRouteArgumentScreen(title: 'Repair estimate');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Repair estimate')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(_jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading estimate...');
          }
          final job = snapshot.data!;
          final estimate = job.estimate;
          if (estimate == null) {
            return const Center(
              child: Text('No estimate has been submitted yet.'),
            );
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Diagnosis', style: AppTextStyles.titleMedium),
                        const SizedBox(height: 4),
                        Text(
                          estimate.diagnosis,
                          style: AppTextStyles.bodyMedium,
                        ),
                        if (estimate.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            estimate.notes,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _EstimateRow(
                          label: 'Labour',
                          amount: estimate.laborCharge,
                        ),
                        _EstimateRow(
                          label: 'Parts',
                          amount: estimate.partsCharge,
                        ),
                        const Divider(),
                        _EstimateRow(
                          label: 'Total',
                          amount: estimate.total,
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Approve estimate',
                  loading: _busy,
                  onPressed: _busy ? null : _approve,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy ? null : _reject,
                  child: const Text('Reject and cancel job'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final String label;
  final double amount;
  final bool bold;
  const _EstimateRow({
    required this.label,
    required this.amount,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = bold ? AppTextStyles.titleMedium : AppTextStyles.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('₹${amount.toStringAsFixed(0)}', style: style),
        ],
      ),
    );
  }
}
