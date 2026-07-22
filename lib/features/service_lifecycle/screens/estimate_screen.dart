import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/job_service.dart';

class EstimateScreen extends StatelessWidget {
  const EstimateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Repair estimate')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Diagnosis'),
                    SizedBox(height: 4),
                    Text('P-trap has failed; replace washer + tighten flange.'),
                    SizedBox(height: 16),
                    _EstimateRow(label: 'Labour', amount: '₹250'),
                    _EstimateRow(label: 'Parts', amount: '₹150'),
                    Divider(),
                    _EstimateRow(label: 'Total', amount: '₹400', bold: true),
                  ],
                ),
              ),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Approve estimate',
              onPressed: () async {
                await JobService.instance.approveEstimate('job-id-stub');
                if (!context.mounted) return;
                Navigator.of(context)
                    .pushReplacementNamed(RouteNames.completion);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                await JobService.instance.rejectEstimate('job-id-stub');
                if (!context.mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Reject and cancel job'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final String label;
  final String amount;
  final bool bold;
  const _EstimateRow({required this.label, required this.amount, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = bold
        ? const TextStyle(fontWeight: FontWeight.bold)
        : const TextStyle();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(amount, style: style)],
      ),
    );
  }
}
