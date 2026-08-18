import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/user_model.dart';
import 'package:fixwaala/features/customer_ticket/models/ticket_model.dart';
import 'package:fixwaala/features/customer_ticket/services/ticket_service.dart';
import 'package:fixwaala/features/geo_broadcast/services/geo_broadcast_service.dart';

const _providerLocation = GeoPoint(12.9716, 77.5946); // Bengaluru
const _farLocation = GeoPoint(13.0796, 77.5946); // ~12 km north

void main() {
  setUp(() {
    TicketService.instance.resetForTesting();
  });

  Future<String> createDemoTicket({
    GeoPoint location = _providerLocation,
    ServiceCategory category = ServiceCategory.plumber,
  }) {
    return TicketService.instance.createTicket(
      Ticket(
        id: '',
        customerId: 'c1',
        description: 'Leaking tap',
        imageUrls: const [],
        category: category,
        complexity: ProblemComplexity.low,
        approximateLocation: location,
        status: TicketStatus.draft,
        createdAt: DateTime.now(),
      ),
    );
  }

  group('TicketService radius/window updates', () {
    test('a new ticket starts at the initial 2 km tier', () async {
      final id = await createDemoTicket();
      final ticket = await TicketService.instance.watchTicket(id).first;
      expect(ticket.broadcastRadiusKm, 2);
      expect(ticket.status, TicketStatus.matching);
    });

    test('updateBroadcastRadius advances the ticket radius', () async {
      final id = await createDemoTicket();

      await TicketService.instance.updateBroadcastRadius(id, 10);
      var ticket = await TicketService.instance.watchTicket(id).first;
      expect(ticket.broadcastRadiusKm, 10);

      await TicketService.instance.updateBroadcastRadius(id, 15);
      ticket = await TicketService.instance.watchTicket(id).first;
      expect(ticket.broadcastRadiusKm, 15);
    });

    test('openCandidateWindow flips status and sets the expiry', () async {
      final id = await createDemoTicket();
      final expiresAt = DateTime.now().add(const Duration(seconds: 30));

      await TicketService.instance.openCandidateWindow(id, expiresAt);

      final ticket = await TicketService.instance.watchTicket(id).first;
      expect(ticket.status, TicketStatus.awaitingCustomerConfirmation);
      expect(ticket.candidateWindowExpiresAt, expiresAt);
    });

    test(
      'assignProvider reveals the exact location and assigns the provider',
      () async {
        final id = await createDemoTicket();
        const exact = GeoPoint(12.9, 77.6);

        await TicketService.instance.assignProvider(
          ticketId: id,
          providerId: 'p1',
          exactLocation: exact,
        );

        final ticket = await TicketService.instance.watchTicket(id).first;
        expect(ticket.status, TicketStatus.assigned);
        expect(ticket.assignedProviderId, 'p1');
        expect(ticket.exactLocation?.latitude, exact.latitude);
        expect(ticket.exactLocation?.longitude, exact.longitude);
      },
    );
  });

  group('GeoBroadcastService.watchNearbyMatchingTickets', () {
    test(
      'excludes a ticket outside its own current broadcast radius',
      () async {
        await createDemoTicket(location: _providerLocation);
        await createDemoTicket(location: _farLocation);

        final results = await GeoBroadcastService.instance
            .watchNearbyMatchingTickets(
              categories: const [ServiceCategory.plumber],
              providerLocation: _providerLocation,
            )
            .first;

        // Default radius is 5 km, so only the co-located ticket matches.
        expect(results.length, 1);
        expect(
          results.single.approximateLocation.latitude,
          _providerLocation.latitude,
        );
      },
    );

    test(
      'includes the far ticket once its radius has expanded to reach it',
      () async {
        final farId = await createDemoTicket(location: _farLocation);
        await TicketService.instance.updateBroadcastRadius(farId, 15);

        final results = await GeoBroadcastService.instance
            .watchNearbyMatchingTickets(
              categories: const [ServiceCategory.plumber],
              providerLocation: _providerLocation,
            )
            .first;

        expect(results.length, 1);
        expect(results.single.id, farId);
      },
    );

    test('excludes tickets outside the requested categories', () async {
      await createDemoTicket(category: ServiceCategory.electrician);

      final results = await GeoBroadcastService.instance
          .watchNearbyMatchingTickets(
            categories: const [ServiceCategory.plumber],
            providerLocation: _providerLocation,
          )
          .first;

      expect(results, isEmpty);
    });
  });
}
