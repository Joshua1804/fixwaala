import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../../core/models/enums.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../features/payment/models/payment_model.dart';
import '../../../core/admin_audit_service.dart';

class PaymentPage {
  final List<PaymentRecord> payments;
  final fs.DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;
  const PaymentPage({
    required this.payments,
    required this.lastDoc,
    required this.hasMore,
  });
}

/// Admin oversight of `payments`. The collection carries denormalised
/// `customerId`/`providerId` specifically so it can be scoped per-party for
/// everyone else; `isAdmin()` in `firestore.rules` bypasses that scoping
/// entirely for exactly this screen.
class AdminPaymentService {
  AdminPaymentService._();
  static final AdminPaymentService instance = AdminPaymentService._();

  fs.CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.firestore.collection('payments');

  Future<PaymentPage> fetchPage({
    PaymentStatus? status,
    PaymentDisputeStatus? disputeStatus,
    fs.DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 25,
  }) async {
    fs.Query<Map<String, dynamic>> query = _col;
    // Rules-driven index choice: `disputeStatus` and `status` each have their
    // own composite with `processedAt`, but not combined with each other —
    // the UI applies one filter at a time.
    if (disputeStatus != null) {
      query = query
          .where('disputeStatus', isEqualTo: disputeStatus.name)
          .orderBy('processedAt', descending: true);
    } else if (status != null) {
      query = query
          .where('status', isEqualTo: status.name)
          .orderBy('processedAt', descending: true);
    } else {
      query = query.orderBy('processedAt', descending: true);
    }
    if (startAfter != null) query = query.startAfterDocument(startAfter);
    final snap = await query.limit(limit + 1).get();
    final docs = snap.docs;
    final hasMore = docs.length > limit;
    final pageDocs = hasMore ? docs.sublist(0, limit) : docs;
    return PaymentPage(
      payments: pageDocs.map((d) => PaymentRecord.fromMap(d.data())).toList(),
      lastDoc: pageDocs.isEmpty ? null : pageDocs.last,
      hasMore: hasMore,
    );
  }

  Future<PaymentRecord?> fetchOne(String id) async {
    final doc = await _col.doc(id).get();
    if (!doc.exists || doc.data() == null) return null;
    return PaymentRecord.fromMap(doc.data()!);
  }

  Future<void> setDispute(
    PaymentRecord payment, {
    required PaymentDisputeStatus status,
    required String note,
    required String adminId,
  }) async {
    final updated = payment.copyWithDispute(
      disputeStatus: status,
      disputeNote: note,
      disputeUpdatedByAdminId: adminId,
    );
    await _col.doc(payment.id).update({
      'disputeStatus': updated.disputeStatus.name,
      'disputeNote': updated.disputeNote,
      'disputeUpdatedAt': fs.Timestamp.fromDate(updated.disputeUpdatedAt!),
      'disputeUpdatedByAdminId': updated.disputeUpdatedByAdminId,
    });
    await AdminAuditService.instance.log(
      action: 'payment.set_dispute',
      targetType: 'payment',
      targetId: payment.id,
      details: {'status': status.name, 'note': note},
    );
  }
}
