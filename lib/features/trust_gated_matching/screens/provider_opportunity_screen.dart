import 'package:flutter/material.dart';

import '../../../core/widgets/custom_button.dart';
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

  Future<void> _accept() async {
    setState(() => _accepting = true);
    final lease = await MatchingService.instance.acceptOpportunity(
      ticketId: 'ticket-id-stub',
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
            const ListTile(
              leading: Icon(Icons.plumbing, size: 40),
              title: Text('Plumbing job nearby'),
              subtitle: Text('~1.2 km · Estimated 20 min'),
            ),
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
