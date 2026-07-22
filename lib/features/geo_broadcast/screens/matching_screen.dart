import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';

class MatchingScreen extends StatelessWidget {
  const MatchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finding provider')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Searching nearby providers',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'We expand the radius from 5 km → 10 km → 15 km until we find someone.',
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
            // Debug helper for skeleton — jump directly to the review screen.
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pushReplacementNamed(RouteNames.providerReview),
              child: const Text('[debug] show provider review'),
            ),
          ],
        ),
      ),
    );
  }
}
