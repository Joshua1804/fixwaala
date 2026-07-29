import 'package:flutter_test/flutter_test.dart';

import 'package:fixwaala/core/models/enums.dart';
import 'package:fixwaala/core/models/user_model.dart';
import 'package:fixwaala/features/customer_ticket/models/ticket_model.dart';
import 'package:fixwaala/features/customer_ticket/services/ticket_service.dart';
import 'package:fixwaala/features/service_lifecycle/services/job_service.dart';
import 'package:fixwaala/features/trust_gated_matching/services/matching_service.dart';

void main() {
  setUp(() {
    TicketService.instance.resetForTesting();
    MatchingService.instance.resetForTesting();
    JobService.instance.resetForTesting();
  });

  Future<String> createDemoTicket() {
    return TicketService.instance.createTicket(
      Ticket(
        id: '',
        customerId: 'c1',
        customerName: 'Customer One',
        description: 'Leaking tap',
        imageUrls: const [],
        category: ServiceCategory.plumber,
        complexity: ProblemComplexity.low,
        approximateLocation: const GeoPoint(12.9716, 77.5946),
        status: TicketStatus.draft,
        createdAt: DateTime.now(),
      ),
    );
  }

  group('MatchingService.acceptOpportunity', () {
    test(
      'creates a pending candidate and opens the review window on first accept',
      () async {
        final ticketId = await createDemoTicket();

        final lease = await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p1',
        );

        expect(lease, isNotNull);
        expect(lease!.status, CandidateStatus.pending);

        final ticket = await TicketService.instance.watchTicket(ticketId).first;
        expect(ticket.status, TicketStatus.awaitingCustomerConfirmation);
        expect(ticket.candidateWindowExpiresAt, isNotNull);
      },
    );

    test(
      'a second acceptance does not reopen an already-open window',
      () async {
        final ticketId = await createDemoTicket();
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p1',
        );
        final firstExpiry =
            (await TicketService.instance.watchTicket(ticketId).first)
                .candidateWindowExpiresAt;

        await Future<void>.delayed(const Duration(milliseconds: 5));
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p2',
        );

        final candidates = await MatchingService.instance
            .watchCandidates(ticketId)
            .first;
        expect(candidates.length, 2);

        final ticketAfterSecond = await TicketService.instance
            .watchTicket(ticketId)
            .first;
        expect(ticketAfterSecond.candidateWindowExpiresAt, firstExpiry);
      },
    );
  });

  group('MatchingService.confirmProvider', () {
    test(
      'assigns the ticket, reveals the exact location, and marks other candidates not selected',
      () async {
        final ticketId = await createDemoTicket();
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p1',
        );
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p2',
        );

        await MatchingService.instance.confirmProvider(
          ticketId: ticketId,
          providerId: 'p1',
          providerName: 'Provider One',
        );

        final ticket = await TicketService.instance.watchTicket(ticketId).first;
        expect(ticket.status, TicketStatus.assigned);
        expect(ticket.assignedProviderId, 'p1');
        expect(ticket.exactLocation, isNotNull);

        final candidates = await MatchingService.instance
            .watchCandidates(ticketId)
            .first;
        final p1 = candidates.firstWhere((c) => c.providerId == 'p1');
        final p2 = candidates.firstWhere((c) => c.providerId == 'p2');
        expect(p1.status, CandidateStatus.selected);
        expect(p2.status, CandidateStatus.notSelected);

        final job = JobService.instance.jobForTicket(ticketId);
        expect(job, isNotNull);
        expect(job!.providerId, 'p1');
      },
    );
  });

  group('MatchingService.rejectCandidate', () {
    test('resumes broadcast once no candidate is left pending', () async {
      final ticketId = await createDemoTicket();
      await MatchingService.instance.acceptOpportunity(
        ticketId: ticketId,
        providerId: 'p1',
      );

      await MatchingService.instance.rejectCandidate(
        ticketId: ticketId,
        providerId: 'p1',
        status: CandidateStatus.expired,
      );

      final ticket = await TicketService.instance.watchTicket(ticketId).first;
      expect(ticket.status, TicketStatus.matching);

      final candidates = await MatchingService.instance
          .watchCandidates(ticketId)
          .first;
      expect(candidates.single.status, CandidateStatus.expired);
    });

    test(
      'does not resume broadcast while another candidate is still pending',
      () async {
        final ticketId = await createDemoTicket();
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p1',
        );
        await MatchingService.instance.acceptOpportunity(
          ticketId: ticketId,
          providerId: 'p2',
        );

        await MatchingService.instance.rejectCandidate(
          ticketId: ticketId,
          providerId: 'p1',
          status: CandidateStatus.expired,
        );

        final ticket = await TicketService.instance.watchTicket(ticketId).first;
        expect(ticket.status, TicketStatus.awaitingCustomerConfirmation);
      },
    );
  });
}
