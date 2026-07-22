import '../../../core/models/enums.dart';
import '../models/ticket_model.dart';

class TicketService {
  TicketService._();
  static final TicketService instance = TicketService._();

  Future<String> createTicket(Ticket draft) async {
    // TODO: write Firestore doc, transition status → matching.
    return 'ticket-id-stub';
  }

  Future<List<String>> uploadImages(List<String> localPaths) async {
    // TODO: upload each to Firebase Storage.
    return [];
  }

  Stream<Ticket> watchTicket(String ticketId) async* {
    // TODO: Firestore snapshot stream.
  }

  Future<List<Ticket>> myTickets(String customerId) async {
    // TODO: query customer tickets.
    return [];
  }

  Future<void> cancelTicket(String ticketId) async {
    // TODO: transition to cancelled + log audit event.
  }

  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    // TODO
  }
}
