import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../services/matching_service.dart';

/// Provider-facing incoming opportunity screen: tap Accept to request a lease.
class ProviderOpportunityScreen extends StatefulWidget {
  const ProviderOpportunityScreen({super.key});

  @override
  State<ProviderOpportunityScreen> createState() =>
      _ProviderOpportunityScreenState();
}

class _ProviderOpportunityScreenState extends State<ProviderOpportunityScreen> {
  bool _accepting = false;
  String _status = 'incoming'; // incoming → awaiting-customer → assigned
  late String _ticketId;
  bool _ranOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranOnce) return;
    _ranOnce = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    _ticketId = args is String ? args : 'ticket-id-stub';
  }

  /// [TicketService.watchTicket] throws synchronously if the id isn't found
  /// in the in-memory fallback store — guard so the stub id doesn't crash
  /// this screen during manual testing.
  Stream<Ticket> _ticketStream(String ticketId) {
    try {
      return TicketService.instance.watchTicket(ticketId);
    } catch (_) {
      return const Stream.empty();
    }
  }

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final lease = await MatchingService.instance.acceptOpportunity(
      ticketId: _ticketId,
      providerId: 'provider-id-stub',
    );
    if (!mounted) return;
    setState(() {
      _accepting = false;
      _status = lease != null ? 'awaiting-customer' : 'lost';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New opportunity')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<Ticket>(
              stream: _ticketStream(_ticketId),
              builder: (context, snapshot) {
                final ticket = snapshot.data;
                if (ticket == null) {
                  return const ListTile(
                    leading: Icon(Icons.handyman_rounded, size: 40),
                    title: Text('Job nearby'),
                    subtitle: Text('~1.2 km · Estimated 20 min'),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        ServiceCategoryUi.icon(ticket.category),
                        size: 40,
                      ),
                      title: Text(
                        '${ServiceCategoryUi.label(ticket.category)} job nearby',
                      ),
                      subtitle: Text(ticket.description),
                    ),
                    if (ticket.imageUrls.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 72,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ticket.imageUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              ticket.imageUrls[i],
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (ticket.recommendedEquipment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Bring with you'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ticket.recommendedEquipment
                            .map((e) => Chip(label: Text(e)))
                            .toList(),
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            const Text(
              'Address will appear only after the customer confirms you.',
            ),
            const Spacer(),
            if (_status == 'incoming')
              PrimaryButton(
                label: 'Accept',
                loading: _accepting,
                onPressed: _accept,
              )
            else if (_status == 'awaiting-customer')
              const Card(
                child: ListTile(
                  leading: Icon(Icons.hourglass_top),
                  title: Text('Waiting for customer to confirm...'),
                  subtitle: Text('This may take up to 30 seconds.'),
                ),
              )
            else if (_status == 'lost')
              const Text(
                'Someone else was assigned first.',
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
