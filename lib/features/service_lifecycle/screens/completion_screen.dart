import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/job_service.dart';

class CompletionScreen extends StatelessWidget {
  const CompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm completion')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Provider marked the repair as complete. Do you confirm?'),
            const Spacer(),
            PrimaryButton(
              label: 'Yes, work is done',
              onPressed: () async {
                await JobService.instance.markCompleted('job-id-stub');
                if (!context.mounted) return;
                Navigator.of(context)
                    .pushReplacementNamed(RouteNames.payment);
              },
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () {
                // TODO: open dispute flow (Module 11).
                Navigator.of(context).pushNamed(RouteNames.report);
              },
              child: const Text('Something is wrong'),
            ),
          ],
        ),
      ),
    );
  }
}
