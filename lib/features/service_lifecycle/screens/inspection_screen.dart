import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';

class InspectionScreen extends StatelessWidget {
  const InspectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
                'Provider is inspecting the issue. You will see the estimate once submitted.'),
            const Spacer(),
            PrimaryButton(
              label: 'Simulate: estimate received',
              onPressed: () =>
                  Navigator.of(context).pushNamed(RouteNames.estimate),
            ),
          ],
        ),
      ),
    );
  }
}
