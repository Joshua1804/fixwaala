import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/ticket_service.dart';

class TicketReviewScreen extends StatelessWidget {
  const TicketReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments
        as Map<String, dynamic>? ??
        const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Review request')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryTile(
                label: 'Category', value: args['category']?.toString() ?? '—'),
            _SummaryTile(
                label: 'Complexity', value: args['complexity']?.toString() ?? '—'),
            _SummaryTile(
                label: 'Description', value: args['description'] ?? '—'),
            _SummaryTile(label: 'Location', value: args['address'] ?? 'Current'),
            const Spacer(),
            const Text(
              'Your exact address stays private until you confirm a provider.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Submit request',
              onPressed: () async {
                // TODO: build Ticket from args, call TicketService.createTicket.
                TicketService.instance;
                if (!context.mounted) return;
                Navigator.of(context)
                    .pushReplacementNamed(RouteNames.matchingProgress);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}
