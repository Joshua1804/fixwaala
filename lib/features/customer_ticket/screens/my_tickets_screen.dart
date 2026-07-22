import 'package:flutter/material.dart';

import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

class MyTicketsScreen extends StatelessWidget {
  const MyTicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My requests')),
      body: FutureBuilder<List<Ticket>>(
        future: TicketService.instance.myTickets('current-customer-id'),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const Center(child: Text('No service requests yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, i) {
              final t = items[i];
              return ListTile(
                title: Text(t.category.name),
                subtitle: Text(t.status.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  // TODO: push detail view.
                },
              );
            },
          );
        },
      ),
    );
  }
}
