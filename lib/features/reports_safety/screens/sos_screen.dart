import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../services/report_service.dart';

/// SOS Screen (Module 11) — emergency alert during an active job.
///
/// Two things were wrong here and both mattered:
///
/// * `_raise` had **no error handling at all**. The alert was written to an
///   in-memory list that could not fail, so the screen always advanced to
///   "Our admin team has been alerted" — a claim that was never true, since
///   nothing ever left the device.
/// * Emergency services were never offered. Even with a working alert queue,
///   routing someone in danger through a support backlog is the wrong
///   default. National emergency numbers are now on the screen itself,
///   before the SOS button, and reachable whether or not the alert succeeds.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _raising = false;
  bool _raised = false;
  String? _error;

  Future<void> _raise(AppUser me, String? jobId) async {
    setState(() {
      _raising = true;
      _error = null;
    });
    try {
      await ReportService.instance.raiseSos(userId: me.id, jobId: jobId);
      if (!mounted) return;
      setState(() {
        _raising = false;
        _raised = true;
      });
    } catch (error) {
      if (!mounted) return;
      // Never report success for an alert that did not send.
      setState(() {
        _raising = false;
        _error = ErrorMessages.friendly(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobId = ModalRoute.of(context)?.settings.arguments as String?;
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency (SOS)')),
      backgroundColor: AppColors.error.withValues(alpha: 0.08),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          final me = snapshot.data;
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Emergency services first — always, regardless of state.
                  // Nothing in this app is a substitute for calling them.
                  const _EmergencyCallouts(),
                  const SizedBox(height: 24),
                  Icon(
                    _raised ? Icons.check_circle : Icons.warning,
                    size: 64,
                    color: _raised ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _raised
                        ? 'SOS recorded'
                        : 'Do you also want to alert Fixwaala?',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _raised
                        ? 'Your alert has been sent to the Fixwaala safety team '
                              'and this job is flagged for review. If you are in '
                              'danger, call the emergency numbers above now.'
                        : 'This flags the job for the Fixwaala safety team to '
                              'review. It is not an emergency service and is not '
                              'monitored 24/7.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Could not send your alert: $_error\n\n'
                        'Please call the emergency numbers above.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  if (!_raised) ...[
                    PrimaryButton(
                      label: _error == null ? 'Raise SOS' : 'Try again',
                      loading: _raising,
                      icon: Icons.emergency,
                      onPressed: me == null ? null : () => _raise(me, jobId),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ] else
                    PrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// India's national emergency numbers, dialable directly.
class _EmergencyCallouts extends StatelessWidget {
  const _EmergencyCallouts();

  static const _numbers = [
    ('112', 'All emergencies', Icons.emergency_share_rounded),
    ('100', 'Police', Icons.local_police_rounded),
    ('108', 'Ambulance', Icons.local_hospital_rounded),
  ];

  Future<void> _dial(String number) async {
    await launchUrl(Uri(scheme: 'tel', path: number));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'In immediate danger?',
            textAlign: TextAlign.center,
            style: AppTextStyles.titleMedium.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            'Call emergency services directly — do not wait for us.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final (number, label, icon) in _numbers) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _dial(number),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: Column(
                      children: [
                        Icon(icon, size: 18),
                        const SizedBox(height: 2),
                        Text(
                          number,
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        Text(label, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ),
                if (number != _numbers.last.$1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
