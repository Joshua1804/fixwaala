import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../services/report_service.dart';

/// SOS Screen (Module 11) — emergency alert during an active job.
class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _raising = false;
  bool _raised = false;

  Future<void> _raise(AppUser me, String? jobId) async {
    setState(() => _raising = true);
    await ReportService.instance.raiseSos(userId: me.id, jobId: jobId);
    if (!mounted) return;
    setState(() {
      _raising = false;
      _raised = true;
    });
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
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  _raised ? Icons.check_circle : Icons.warning,
                  size: 72,
                  color: _raised ? AppColors.success : AppColors.error,
                ),
                const SizedBox(height: 16),
                Text(
                  _raised ? 'SOS raised' : 'Do you need immediate help?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _raised
                      ? 'Our admin team has been alerted and will follow up immediately.'
                      : 'Raising SOS notifies the Fixwaala admin team and flags this job for review.',
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (!_raised) ...[
                  PrimaryButton(
                    label: 'Raise SOS',
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
          );
        },
      ),
    );
  }
}
