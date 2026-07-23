import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../services/report_service.dart';

/// Report/Dispute Screen (Module 11).
///
/// Reachable from an active job (pre-filled with jobId/againstUserId) or
/// standalone from a user's profile.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  String _reason = 'Provider misbehaved';
  ReportSeverity _severity = ReportSeverity.medium;
  bool _submitting = false;
  String? _error;

  Map<String, dynamic> _args(BuildContext context) =>
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
      const {};

  Future<void> _confirmAndSubmit(AppUser me, Map<String, dynamic> args) async {
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _error = 'Please describe what happened.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit this report?'),
        content: const Text(
          'Our admin team will review it. False reports may affect your account standing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _submit(me, args);
  }

  Future<void> _submit(AppUser me, Map<String, dynamic> args) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ReportService.instance.submitReport(
        reporterId: me.id,
        reason: _reason,
        description: _descriptionController.text,
        severity: _severity,
        againstUserId: args['againstUserId'] as String?,
        jobId: args['jobId'] as String?,
        ticketId: args['ticketId'] as String?,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. Our team will review it.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = _args(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final me = snapshot.data;
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _reason,
                  items:
                      const [
                            'Provider misbehaved',
                            'Customer misbehaved',
                            'Poor quality of work',
                            'Payment issue',
                            'Other',
                          ]
                          .map(
                            (r) => DropdownMenuItem(value: r, child: Text(r)),
                          )
                          .toList(),
                  onChanged: (v) => setState(() => _reason = v!),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Describe what happened',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Severity'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: ReportSeverity.values
                      .map(
                        (s) => ChoiceChip(
                          label: Text(s.name),
                          selected: _severity == s,
                          onSelected: (_) => setState(() => _severity = s),
                        ),
                      )
                      .toList(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const Spacer(),
                PrimaryButton(
                  label: 'Submit report',
                  loading: _submitting,
                  onPressed: me == null
                      ? null
                      : () => _confirmAndSubmit(me, args),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
