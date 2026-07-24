import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
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
      );
      try {
        await docRef.set(ticket.toMap());
        return docRef.id;
      } on FirebaseException catch (e) {
        if (kDebugMode && e.code == 'permission-denied') {
          debugPrint(
            '[TicketService] Firestore denied ticket create; using debug '
            'simulation fallback. Update Firestore rules before release.',
          );
          return _createInMemory(draft);
        }
        rethrow;
      }
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
    );
    _memStore[id] = ticket;
    debugPrint('[TicketService] Created ticket $id (simulation)');
    return id;
  }

  // ── Upload images ──────────────────────────────────────────────

  Future<List<String>> uploadImages(List<String> localPaths) async {
    // TODO: upload each to Firebase Storage when configured.
    return localPaths;
  }

  // ── Read: single ticket ────────────────────────────────────────

  Stream<Ticket> watchTicket(String ticketId) {
    if (_live) {
      return _col.doc(ticketId).snapshots().where((s) => s.exists).map(
        (snap) => Ticket.fromMap(snap.data()!),
      );
    } else {
      // Emit current value once.
      return Stream.value(_memStore[ticketId]!);
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
      final list = _memStore.values
          .where((t) => t.customerId == customerId)
          .toList()
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
      final list = _memStore.values
          .where((t) => t.customerId == customerId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    }
  }

  /// Real-time stream of all tickets waiting to be matched/accepted.
  Stream<List<Ticket>> watchMatchingTickets() {
    if (_live) {
      return _col
          .where('status', isEqualTo: TicketStatus.matching.name)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (snap) => snap.docs.map((d) => Ticket.fromMap(d.data())).toList(),
          );
    } else {
      final list = _memStore.values
          .where((t) => t.status == TicketStatus.matching)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Stream.value(list);
    }
  }

  // ── Update status ──────────────────────────────────────────────

  Future<void> updateStatus(String ticketId, TicketStatus status) async {
    if (_live) {
      await _col.doc(ticketId).update({
        'status': status.name,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
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

  // ── Cancel ─────────────────────────────────────────────────────

  Future<void> cancelTicket(String ticketId) async {
    await updateStatus(ticketId, TicketStatus.cancelled);
  }
}
