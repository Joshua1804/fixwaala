import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/models/enums.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../features/customer_ticket/models/ticket_model.dart';
import '../../../../features/service_lifecycle/models/job_model.dart';
import '../../../core/admin_audit_service.dart';

class TicketPage {
  final List<Ticket> tickets;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const TicketPage({required this.tickets, required this.lastDoc, required this.hasMore});
}

class JobPage {
  final List<Job> jobs;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const JobPage({required this.jobs, required this.lastDoc, required this.hasMore});
}

/// Cross-user oversight of the marketplace's two core records. Reads and
/// writes here work because `firestore.rules` grants `isAdmin()`
/// unrestricted access on both `tickets` and `jobs` — the same admin bypass
/// that lets the mobile app's per-user scoping stay tight for everyone else.
class AdminTicketJobService {
  AdminTicketJobService._();
  static final AdminTicketJobService instance = AdminTicketJobService._();

  fs.CollectionReference<Map<String, dynamic>> get _ticketsCol =>
      FirebaseService.instance.firestore.collection('tickets');
  fs.CollectionReference<Map<String, dynamic>> get _openTicketsCol =>
      FirebaseService.instance.firestore.collection('openTickets');
  fs.CollectionReference<Map<String, dynamic>> get _jobsCol =>
      FirebaseService.instance.firestore.collection('jobs');

  Future<TicketPage> fetchTicketPage({
    TicketStatus? status,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _ticketsCol;
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return TicketPage(
      tickets: pageDocs.map((d) => Ticket.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<Ticket?> fetchTicket(String id) async {
    final doc = await _ticketsCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Ticket.fromMap(doc.data()!);
  }

  /// The job created for [ticketId], if any — a ticket only has one once a
  /// provider is confirmed.
  Future<Job?> fetchJobForTicket(String ticketId) async {
    final snap = await _jobsCol
        .where('ticketId', isEqualTo: ticketId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return Job.fromMap(snap.docs.first.data());
  }

  /// Cancels a ticket that is stuck — e.g. flagged in a report and needs to
  /// stop broadcasting immediately. Mirrors what
  /// `TicketService._syncBroadcast` does for a normal status change: the
  /// redacted `openTickets` projection is removed in the same batch, so no
  /// provider keeps seeing a request an admin has just killed.
  Future<void> forceCancelTicket(Ticket ticket, {required String reason}) async {
    final batch = FirebaseService.instance.firestore.batch();
    batch.update(_ticketsCol.doc(ticket.id), {
      'status': TicketStatus.cancelled.name,
      'updatedAt': fs.Timestamp.fromDate(DateTime.now()),
    });
    batch.delete(_openTicketsCol.doc(ticket.id));
    await batch.commit();
    await AdminAuditService.instance.log(
      action: 'ticket.force_cancel',
      targetType: 'ticket',
      targetId: ticket.id,
      details: {'reason': reason, 'previousStatus': ticket.status.name},
    );
  }

  Future<JobPage> fetchJobPage({
    JobStatus? status,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _jobsCol;
    if (status != null) {
      query = query.where('status', isEqualTo: status.name);
    }
    query = query.orderBy('createdAt', descending: true);
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return JobPage(
      jobs: pageDocs.map((d) => Job.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<Job?> fetchJob(String id) async {
    final doc = await _jobsCol.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return Job.fromMap(doc.data()!);
  }

  Future<void> forceCancelJob(Job job, {required String reason}) async {
    await _jobsCol.doc(job.jobId).update({
      'status': JobStatus.cancelled.name,
      'cancellationReason': reason,
    });
    await AdminAuditService.instance.log(
      action: 'job.force_cancel',
      targetType: 'job',
      targetId: job.jobId,
      details: {'reason': reason, 'previousStatus': job.status.name},
    );
  }
}
