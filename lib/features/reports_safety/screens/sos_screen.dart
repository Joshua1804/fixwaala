import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

class SosScreen extends StatelessWidget {
  const SosScreen({super.key});

  Future<void> _raise(BuildContext context) async {
    await ReportService.instance.raiseSos(
      SafetyAlert(
        id: 'alert-${DateTime.now().microsecondsSinceEpoch}',
        userId: 'current-user-id',
        ticketId: 'ticket-id-stub',
        raisedAt: DateTime.now(),
      ),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('SOS raised. Admin has been alerted.')),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Emergency (SOS)')),
      backgroundColor: Colors.red.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.warning, size: 72, color: Colors.red),
            const SizedBox(height: 16),
            Text('Do you need immediate help?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Raising SOS notifies the Fixwaala admin team and flags this ticket for review.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Raise SOS',
              onPressed: () => _raise(context),
              icon: Icons.emergency,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
