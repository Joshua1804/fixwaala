import 'package:cloud_firestore/cloud_firestore.dart' hide GeoPoint;
import 'package:cloud_firestore/cloud_firestore.dart' as fs show GeoPoint;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart' show GeoPoint;
import '../../../core/services/firebase_service.dart';
import '../models/ticket_model.dart';

/// Ticket CRUD backed by Firestore when Firebase is configured,
/// falling back to in-memory simulation otherwise.
class TicketService {
  TicketService._();
  static final TicketService instance = TicketService._();

  // ── In-memory fallback store ────────────────────────────────────
  final Map<String, Ticket> _memStore = {};
  int _seq = 0;

  bool get _live => FirebaseService.instance.isInitialized;
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('tickets');

  /// Redacted projections of tickets currently in [TicketStatus.matching].
  /// This is the only ticket data an unassigned provider can read — see
  /// [Ticket.toBroadcastMap] and the `openTickets` rule.
  CollectionReference<Map<String, dynamic>> get _openCol =>
      FirebaseService.instance.firestore.collection('openTickets');

  /// Clears all in-memory state. Test-only.
  @visibleForTesting
  void resetForTesting() {
    _memStore.clear();
    _seq = 0;
  }

  // ── Create ──────────────────────────────────────────────────────

  Future<String> createTicket(Ticket draft) async {
    if (_live) {
      final docRef = _col.doc();
      final ticket = Ticket(
        id: docRef.id,
        customerId: draft.customerId,
        customerName: draft.customerName,
        description: draft.description,
        imageUrls: draft.imageUrls,
        category: draft.category,
        complexity: draft.complexity,
        approximateLocation: draft.approximateLocation,
        status: TicketStatus.matching,
        createdAt: DateTime.now(),
        addressLine: draft.addressLine,
        clarifyingQa: draft.clarifyingQa,
        aiSummary: draft.aiSummary,
        recommendedEquipment: draft.recommendedEquipment,
      );
      // Both documents in one batch. Written as two sequential `set` calls,
      // a rejected projection left the private ticket behind as an orphan
      // that no provider could ever discover.
      final batch = FirebaseService.instance.firestore.batch();
      batch.set(docRef, ticket.toMap());
      // The redacted copy is what nearby providers discover; it carries no
      // exact address, street line, or full customer name.
      batch.set(_openCol.doc(docRef.id), ticket.toBroadcastMap());
      await batch.commit();
      return docRef.id;
    } else {
      return _createInMemory(draft);
    }
  }

  String _createInMemory(Ticket draft) {
    _seq += 1;
    final now = DateTime.now();
    final id = 'ticket-$_seq-${now.microsecondsSinceEpoch}';
    final ticket = Ticket(
      id: id,
      customerId: draft.customerId,
      customerName: draft.customerName,
      description: draft.description,
      imageUrls: draft.imageUrls,
      category: draft.category,
      complexity: draft.complexity,
      approximateLocation: draft.approximateLocation,
      status: TicketStatus.matching,
      createdAt: now,
      addressLine: draft.addressLine,
      clarifyingQa: draft.clarifyingQa,
      aiSummary: draft.aiSummary,
      recommendedEquipment: draft.recommendedEquipment,
    );
    _memStore[id] = ticket;
    debugPrint('[TicketService] Created ticket $id (simulation)');
    return id;
  }

  // ── Read: single ticket ────────────────────────────────────────

  Stream<Ticket> watchTicket(String ticketId) {
    if (_live) {
      return _col
          .doc(ticketId)
          .snapshots()
          .where((s) => s.exists)
          .map((snap) => Ticket.fromMap(snap.data()!));
    } else {
      final ticket = _memStore[ticketId];
      if (ticket == null) {
        // Previously `_memStore[ticketId]!`, which threw synchronously the
        // moment a caller passed an id this store had never seen — so callers
        // wrapped it in try/catch instead of the stream simply erroring.
        // Reporting it through the stream lets AsyncStateBuilder show a real
        // message with a retry.
        return Stream.error(StateError('Ticket $ticketId no longer exists.'));
      }
      return Stream.value(ticket);
    }
  }

  // ── Read: customer's tickets ───────────────────────────────────

  /// Returns ALL tickets for [customerId], newest first.
  Future<List<Ticket>> myTickets(String customerId) async {
    if (_live) {
      final snap = await _col
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => Ticket.fromMap(d.data())).toList();
    } else {
      final list =
          _memStore.values.where((t) => t.customerId == customerId).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }
  }

  /// Returns only ACTIVE tickets for [customerId].
  Future<List<Ticket>> activeTickets(String customerId) async {
    final all = await myTickets(customerId);
    return all.where((t) => t.isActive).toList();
  }

  /// Returns only PAST (completed / cancelled / closed) tickets.
  Future<List<Ticket>> historyTickets(String customerId) async {
    final all = await myTickets(customerId);
    return all.where((t) => !t.isActive).toList();
  }

  /// Real-time stream of a customer's tickets, newest first.
  Stream<List<Ticket>> watchMyTickets(String customerId) {
    if (_live) {
      return _col
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => Ticket.fromMap(d.data())).toList(),
          );
    } else {
      // Emit current snapshot once.
      final list =
          _memStore.values.where((t) => t.customerId == customerId).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    }
  }

  /// Real-time stream of all tickets waiting to be matched/accepted.
  ///
  /// When [categories] is non-empty, results are restricted to tickets
  /// whose `category` is one of them (a provider's skill set) — this is
  /// the Firestore-side half of geo-broadcast's provider-pull query; the
  /// caller (see [GeoBroadcastService.watchNearbyMatchingTickets]) applies
  /// the radius filter client-side on top of this.
  Stream<List<Ticket>> watchMatchingTickets({
    List<ServiceCategory> categories = const [],
  }) {
    // An empty skill set used to skip the `whereIn` filter entirely, so a
    // provider who had selected no skills was broadcast *every* category's
    // tickets — the opposite of the intent.
    if (categories.isEmpty) return Stream.value(const []);

    if (_live) {
      Query<Map<String, dynamic>> query = _openCol.where(
        'status',
        isEqualTo: TicketStatus.matching.name,
      );
      if (categories.isNotEmpty) {
        query = query.where(
          'category',
          whereIn: categories.map((c) => c.name).toList(),
        );
      }
      return query
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => Ticket.fromMap(d.data())).toList(),
          );
    } else {
      final list =
          _memStore.values
              .where(
                (t) =>
                    t.status == TicketStatus.matching &&
                    categories.contains(t.category),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    }
  }

  /// Advances a ticket's search radius during geo-broadcast expansion.
  Future<void> updateBroadcastRadius(String ticketId, double radiusKm) async {
    if (_live) {
      final now = Timestamp.fromDate(DateTime.now());
      await _col.doc(ticketId).update({
        'broadcastRadiusKm': radiusKm,
        'updatedAt': now,
      });
      // Targeted mirror rather than a full republish — expansion runs on a
      // timer and does not need to re-read the ticket each tick.
      await _openCol.doc(ticketId).update({
        'broadcastRadiusKm': radiusKm,
        'updatedAt': now,
      });
    } else {
      final existing = _memStore[ticketId];
      if (existing != null) {
        _memStore[ticketId] = existing.copyWith(
          broadcastRadiusKm: radiusKm,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  /// Keeps `openTickets/{id}` in step with the private ticket.
  ///
  /// A ticket is discoverable exactly while it is matching: republished when
  /// it (re-)enters that state, removed the moment it leaves. Removing it is
  /// what stops a provider from continuing to see a request that has already
  /// been assigned to someone else.
  Future<void> _syncBroadcast(String ticketId) async {
    if (!_live) return;
    final doc = await _col.doc(ticketId).get();
    if (!doc.exists || doc.data() == null) return;
    final ticket = Ticket.fromMap(doc.data()!);
    if (ticket.status == TicketStatus.matching) {
      await _openCol.doc(ticketId).set(ticket.toBroadcastMap());
    } else {
      await _openCol.doc(ticketId).delete();
    }
  }

  // ── Update status ──────────────────────────────────────────────

  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    if (_live) {
      await _col.doc(ticketId).update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await _syncBroadcast(ticketId);
    } else {
      final existing = _memStore[ticketId];
      if (existing != null) {
        _memStore[ticketId] = existing.copyWith(
          status: status,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  /// Opens the customer's candidate-review window: flips to
  /// [TicketStatus.awaitingCustomerConfirmation] and starts the shared
  /// countdown. Called once, when a ticket's first candidate accepts.
  Future<void> openCandidateWindow(String ticketId, DateTime expiresAt) async {
    if (_live) {
      await _col.doc(ticketId).update({
        'status': TicketStatus.awaitingCustomerConfirmation.name,
        'candidateWindowExpiresAt': Timestamp.fromDate(expiresAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await _syncBroadcast(ticketId);
    } else {
      final existing = _memStore[ticketId];
      if (existing != null) {
        _memStore[ticketId] = existing.copyWith(
          status: TicketStatus.awaitingCustomerConfirmation,
          candidateWindowExpiresAt: expiresAt,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  /// Reveals the exact location to the confirmed provider and assigns them
  /// to the ticket.
  Future<void> assignProvider({
    required String ticketId,
    required String providerId,
    required GeoPoint exactLocation,
  }) async {
    if (_live) {
      await _col.doc(ticketId).update({
        'assignedProviderId': providerId,
        'exactLocation': fs.GeoPoint(
          exactLocation.latitude,
          exactLocation.longitude,
        ),
        'status': TicketStatus.assigned.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      await _syncBroadcast(ticketId);
    } else {
      final existing = _memStore[ticketId];
      if (existing != null) {
        _memStore[ticketId] = existing.copyWith(
          assignedProviderId: providerId,
          exactLocation: exactLocation,
          status: TicketStatus.assigned,
          updatedAt: DateTime.now(),
        );
      }
    }
  }

  // ── Cancel ─────────────────────────────────────────────────────

  Future<void> cancelTicket(String ticketId) async {
    await updateStatus(ticketId, TicketStatus.cancelled);
  }
}
