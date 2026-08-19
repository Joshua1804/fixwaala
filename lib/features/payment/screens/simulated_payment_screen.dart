import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/payment_model.dart';
import '../services/payment_service.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';

enum _Stage { review, processing, success, failure }

/// Simulated Payment Screen (Module 8) — no real gateway, no real money.
///
/// The outcome is controlled rather than random: a clearly-labelled "demo"
/// switch lets the customer deliberately trigger a failed payment to see
/// the retry path, while the default path succeeds.
class SimulatedPaymentScreen extends StatefulWidget {
  final String? jobId;
  const SimulatedPaymentScreen({super.key, this.jobId});

  @override
  State<SimulatedPaymentScreen> createState() => _SimulatedPaymentScreenState();
}

class _SimulatedPaymentScreenState extends State<SimulatedPaymentScreen> {
  String _method = 'upi';
  bool _simulateFailure = false;
  _Stage _stage = _Stage.review;
  PaymentRecord? _result;

  /// Empty when this route was opened without a job id — [build] guards on
  /// it and shows a real message. This used to be
  /// `ModalRoute.of(context)!.settings.arguments as String`, which threw on
  /// both the `!` and the cast, so arriving here from a notification tap or a
  /// restored navigation stack crashed the screen.
  String get _jobId =>
      widget.jobId ??
      ModalRoute.of(context)?.settings.arguments as String? ??
      '';

  Future<void> _confirmAndPay(double amount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm payment'),
        content: Text(
          'Pay ₹${amount.toStringAsFixed(0)} via ${_method.toUpperCase()}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Pay'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _pay(amount);
  }

  Future<void> _pay(double amount) async {
    setState(() => _stage = _Stage.processing);
    try {
      final result = await PaymentService.instance.simulate(
        jobId: _jobId,
        amount: amount,
        method: _method,
        forceFailure: _simulateFailure,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _stage = result.status == PaymentStatus.success
            ? _Stage.success
            : _Stage.failure;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.review);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_jobId.isEmpty) {
      return const MissingRouteArgumentScreen(title: 'Payment');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(_jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job...');
          }
          final job = snapshot.data!;
          final amount = job.estimate?.total ?? 0;

          switch (_stage) {
            case _Stage.processing:
              return const LoadingWidget(label: 'Processing payment...');
            case _Stage.success:
              return _ResultView(
                success: true,
                amount: amount,
                onContinue: () => Navigator.of(context).pushReplacementNamed(
                  RouteNames.rating,
                  arguments: {
                    'jobId': job.jobId,
                    'toUserId': job.providerId,
                    'toName': job.providerName,
                    'direction': RatingDirection.customerToProvider,
                  },
                ),
              );
            case _Stage.failure:
              return _ResultView(
                success: false,
                amount: amount,
                failureReason: _result?.failureReason,
                onContinue: () => setState(() => _stage = _Stage.review),
                continueLabel: 'Try again',
              );
            case _Stage.review:
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.screenHPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Amount due: ₹${amount.toStringAsFixed(0)}',
                      style: AppTextStyles.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    for (final method in const ['upi', 'card', 'cash'])
                      RadioListTile<String>(
                        value: method,
                        // ignore: deprecated_member_use
                        groupValue: _method,
                        // ignore: deprecated_member_use
                        onChanged: (v) => setState(() => _method = v!),
                        title: Text(method.toUpperCase()),
                      ),
                    const Divider(height: 32),
                    SwitchListTile(
                      value: _simulateFailure,
                      onChanged: (v) => setState(() => _simulateFailure = v),
                      title: const Text('Simulate a failed payment (demo)'),
                      subtitle: const Text('Lets you preview the retry flow.'),
                    ),
                    const Spacer(),
                    PrimaryButton(
                      label: 'Pay now',
                      onPressed: amount <= 0
                          ? null
                          : () => _confirmAndPay(amount),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Simulated payment — no real money is moved.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              );
          }
        },
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final bool success;
  final double amount;
  final String? failureReason;
  final VoidCallback onContinue;
  final String continueLabel;

  const _ResultView({
    required this.success,
    required this.amount,
    required this.onContinue,
    this.failureReason,
    this.continueLabel = 'Continue',
  });

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : AppColors.error;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.screenHPad),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            success ? Icons.check_circle_rounded : Icons.error_rounded,
            size: 72,
            color: color,
          ),
          const SizedBox(height: 16),
          Text(
            success ? 'Payment successful' : 'Payment failed',
            style: AppTextStyles.headlineSmall.copyWith(color: color),
          ),
          const SizedBox(height: 8),
          Text(
            success
                ? '₹${amount.toStringAsFixed(0)} paid successfully.'
                : failureReason ?? 'Something went wrong. Please try again.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: continueLabel, onPressed: onContinue),
        ],
      ),
    );
  }
}
