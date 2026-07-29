import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../../trust_gated_matching/models/candidate_lease.dart';
import '../../trust_gated_matching/services/matching_service.dart';
import '../services/geo_broadcast_service.dart';

/// Customer-facing searching screen. Drives (and displays) the expanding
/// 5→10→15 km geo-broadcast, then auto-navigates the moment a provider
/// accepts (Module 5).
class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> {
  String? _ticketId;
  Stream<Ticket>? _ticketStream;
  Stream<List<CandidateLease>>? _candidatesStream;
  bool _navigated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ticketId == null) {
      final ticketId = ModalRoute.of(context)!.settings.arguments as String;
      _ticketId = ticketId;
      _ticketStream = GeoBroadcastService.instance.runBroadcast(ticketId);
      _candidatesStream = MatchingService.instance.watchCandidates(ticketId);
    }
  }

  void _maybeNavigateToReview(List<CandidateLease> candidates) {
    if (_navigated) return;
    final hasPending = candidates.any(
      (c) => c.status == CandidateStatus.pending,
    );
    if (!hasPending) return;
    _navigated = true;
    NotificationService.instance.showLocalAlert(
      title: 'A provider accepted your request!',
      body: 'Review their details and confirm to reveal your address.',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacementNamed(RouteNames.providerReview, arguments: _ticketId);
    });
  }

  Future<void> _retry() async {
    final ticketId = _ticketId!;
    await TicketService.instance.updateBroadcastRadius(
      ticketId,
      AppConstants.searchRadiiKm.first,
    );
    await TicketService.instance.updateStatus(ticketId, TicketStatus.matching);
    if (!mounted) return;
    setState(() {
      _navigated = false;
      _ticketStream = GeoBroadcastService.instance.runBroadcast(ticketId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finding provider')),
      body: StreamBuilder<List<CandidateLease>>(
        stream: _candidatesStream,
        builder: (context, candSnap) {
          final candidates = candSnap.data ?? const <CandidateLease>[];
          _maybeNavigateToReview(candidates);

          return StreamBuilder<Ticket>(
            stream: _ticketStream,
            builder: (context, ticketSnap) {
              final ticket = ticketSnap.data;

              if (ticket != null && ticket.status == TicketStatus.failed) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: EmptyStateWidget(
                    icon: Icons.search_off_rounded,
                    title: 'No providers found nearby',
                    subtitle:
                        'We expanded the search up to 15 km but no one accepted in time.',
                    actionLabel: 'Try again',
                    onAction: _retry,
                  ),
                );
              }

              final radiusKm = ticket?.broadcastRadiusKm ?? 5;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const LoadingWidget(label: 'Searching nearby providers'),
                    const SizedBox(height: 8),
                    Text(
                      'Searching within ${radiusKm.toStringAsFixed(0)} km '
                      '(expands up to 15 km)...',
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
