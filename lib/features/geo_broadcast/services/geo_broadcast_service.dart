import 'dart:async';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../customer_ticket/services/ticket_service.dart';

/// Expanding-radius geo-broadcast (Module 5). There is no push backend, so
/// this is a two-sided pull design: the customer's device drives the
/// ticket's `broadcastRadiusKm` through [AppConstants.searchRadiiKm] on a
/// timer ([runBroadcast]), while each online provider independently polls
/// for matching, in-range tickets ([watchNearbyMatchingTickets]). Neither
/// side ever queries the other's private data directly.
class GeoBroadcastService {
  GeoBroadcastService._();
  static final GeoBroadcastService instance = GeoBroadcastService._();

  /// Customer-side driver. Emits the ticket every time it changes (status
  /// or radius tier) and, on a [AppConstants.broadcastTimeoutSeconds] timer,
  /// advances `broadcastRadiusKm` to the next tier in
  /// [AppConstants.searchRadiiKm] as long as the ticket is still
  /// [TicketStatus.matching]. Once every tier has been tried with no
  /// candidate, the ticket is marked [TicketStatus.failed].
  Stream<Ticket> runBroadcast(String ticketId) {
    late final StreamController<Ticket> controller;
    StreamSubscription<Ticket>? ticketSub;
    Timer? timer;
    var tierIndex = 0;

    Future<void> advance() async {
      final ticket = await TicketService.instance.watchTicket(ticketId).first;
      if (ticket.status != TicketStatus.matching) {
        timer?.cancel();
        return;
      }
      tierIndex += 1;
      if (tierIndex >= AppConstants.searchRadiiKm.length) {
        timer?.cancel();
        await TicketService.instance.updateStatus(
          ticketId,
          TicketStatus.failed,
        );
        return;
      }
      await TicketService.instance.updateBroadcastRadius(
        ticketId,
        AppConstants.searchRadiiKm[tierIndex],
      );
    }

    controller = StreamController<Ticket>.broadcast(
      onListen: () {
        ticketSub = TicketService.instance
            .watchTicket(ticketId)
            .listen(controller.add, onError: controller.addError);
        timer = Timer.periodic(
          const Duration(seconds: AppConstants.broadcastTimeoutSeconds),
          (_) => advance(),
        );
      },
      onCancel: () {
        timer?.cancel();
        ticketSub?.cancel();
      },
    );
    return controller.stream;
  }

  /// Provider-side pull query: matching, in-progress tickets whose category
  /// is one of [categories] (a provider's skills), filtered client-side to
  /// those within the ticket's own current `broadcastRadiusKm` of
  /// [providerLocation] — Firestore has no way to filter by computed
  /// distance, so the equality filters (status/category) happen server-side
  /// and the radius check happens here.
  Stream<List<Ticket>> watchNearbyMatchingTickets({
    required List<ServiceCategory> categories,
    required GeoPoint providerLocation,
  }) {
    return TicketService.instance
        .watchMatchingTickets(categories: categories)
        .map(
          (tickets) => tickets.where((t) {
            final distanceKm = LocationService.instance.distanceKm(
              providerLocation,
              t.approximateLocation,
            );
            return distanceKm <= t.broadcastRadiusKm;
          }).toList(),
        );
  }
}
