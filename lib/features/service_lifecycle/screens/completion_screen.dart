import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';

/// Customer-facing Completion Confirmation Screen.
///
/// Shown once the provider has requested completion. The customer confirms
/// the repair is actually done before the job can move to payment.
class CompletionScreen extends StatefulWidget {
  final String? jobId;
  const CompletionScreen({super.key, this.jobId});

  @override
  State<CompletionScreen> createState() => _CompletionScreenState();
}

class _CompletionScreenState extends State<CompletionScreen> {
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

  Future<void> _confirm() async {
    setState(() => _busy = true);
    try {
      await JobService.instance.confirmCompletion(_jobId);
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(RouteNames.payment, arguments: _jobId);
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
      return const MissingRouteArgumentScreen(title: 'Confirm completion');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm completion')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchJob(_jobId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const LoadingWidget(label: 'Loading job...');
          }
          final job = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.task_alt_rounded, size: 64),
                const SizedBox(height: 16),
                Text(
                  '${job.providerName} marked the repair as complete.',
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please confirm the work is actually finished before continuing to payment.',
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Yes, work is done',
                  loading: _busy,
                  onPressed: _busy ? null : _confirm,
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pushNamed(
                    RouteNames.report,
                    arguments: {
                      'jobId': job.jobId,
                      'againstUserId': job.providerId,
                    },
                  ),
                  child: const Text('Something is wrong'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
