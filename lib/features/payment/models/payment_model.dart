import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/models/enums.dart';

/// Moderation state of a payment, distinct from [PaymentStatus] — that
/// tracks whether the simulated charge itself succeeded; this tracks whether
/// an admin has had to intervene in it afterwards. Set only by the admin
/// website; see the `payments` rule in `firestore.rules`.
enum PaymentDisputeStatus { none, disputed, resolved, refunded }

class PaymentRecord {
  final String id;
  final String jobId;

  /// Denormalised from the job so a payment can be scoped to its two
  /// participants — both by the client query and by `firestore.rules`.
  /// Without these the collection can only be read wholesale.
  final String customerId;
  final String providerId;

  final double amount;
  final String method; // simulated: 'upi', 'card', 'cash'
  final PaymentStatus status;
  final String? failureReason;
  final DateTime processedAt;

  /// Admin-only moderation fields. See [PaymentDisputeStatus].
  final PaymentDisputeStatus disputeStatus;
  final String? disputeNote;
  final DateTime? disputeUpdatedAt;
  final String? disputeUpdatedByAdminId;

  const PaymentRecord({
    required this.id,
    required this.jobId,
    required this.customerId,
    required this.providerId,
    required this.amount,
    required this.method,
    required this.status,
    required this.processedAt,
    this.failureReason,
    this.disputeStatus = PaymentDisputeStatus.none,
    this.disputeNote,
    this.disputeUpdatedAt,
    this.disputeUpdatedByAdminId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'jobId': jobId,
    'customerId': customerId,
    'providerId': providerId,
    'amount': amount,
    'method': method,
    'status': status.name,
    if (failureReason != null) 'failureReason': failureReason,
    'processedAt': fs.Timestamp.fromDate(processedAt),
    'disputeStatus': disputeStatus.name,
    if (disputeNote != null) 'disputeNote': disputeNote,
    if (disputeUpdatedAt != null)
      'disputeUpdatedAt': fs.Timestamp.fromDate(disputeUpdatedAt!),
    if (disputeUpdatedByAdminId != null)
      'disputeUpdatedByAdminId': disputeUpdatedByAdminId,
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'] as String,
    jobId: map['jobId'] as String,
    customerId: map['customerId'] as String? ?? '',
    providerId: map['providerId'] as String? ?? '',
    amount: (map['amount'] as num).toDouble(),
    method: map['method'] as String? ?? '',
    status: PaymentStatus.values.byNameOrDefault(
      map['status'] as String?,
      PaymentStatus.pending,
    ),
    failureReason: map['failureReason'] as String?,
    processedAt: map['processedAt'] is fs.Timestamp
        ? (map['processedAt'] as fs.Timestamp).toDate()
        : DateTime.tryParse(map['processedAt']?.toString() ?? '') ??
              DateTime.now(),
    disputeStatus: PaymentDisputeStatus.values.byNameOrDefault(
      map['disputeStatus'] as String?,
      PaymentDisputeStatus.none,
    ),
    disputeNote: map['disputeNote'] as String?,
    disputeUpdatedAt: map['disputeUpdatedAt'] is fs.Timestamp
        ? (map['disputeUpdatedAt'] as fs.Timestamp).toDate()
        : null,
    disputeUpdatedByAdminId: map['disputeUpdatedByAdminId'] as String?,
  );

  PaymentRecord copyWithDispute({
    required PaymentDisputeStatus disputeStatus,
    String? disputeNote,
    required String disputeUpdatedByAdminId,
  }) {
    return PaymentRecord(
      id: id,
      jobId: jobId,
      customerId: customerId,
      providerId: providerId,
      amount: amount,
      method: method,
      status: status,
      processedAt: processedAt,
      failureReason: failureReason,
      disputeStatus: disputeStatus,
      disputeNote: disputeNote,
      disputeUpdatedAt: DateTime.now(),
      disputeUpdatedByAdminId: disputeUpdatedByAdminId,
    );
  }
}
