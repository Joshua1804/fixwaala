import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/models/enums.dart';

class PaymentRecord {
  final String id;
  final String jobId;
  final double amount;
  final String method; // simulated: 'upi', 'card', 'cash'
  final PaymentStatus status;
  final String? failureReason;
  final DateTime processedAt;

  const PaymentRecord({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.method,
    required this.status,
    required this.processedAt,
    this.failureReason,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'jobId': jobId,
    'amount': amount,
    'method': method,
    'status': status.name,
    if (failureReason != null) 'failureReason': failureReason,
    'processedAt': fs.Timestamp.fromDate(processedAt),
  };

  factory PaymentRecord.fromMap(Map<String, dynamic> map) => PaymentRecord(
    id: map['id'] as String,
    jobId: map['jobId'] as String,
    amount: (map['amount'] as num).toDouble(),
    method: map['method'] as String? ?? '',
    status: PaymentStatus.values.byName(
      map['status'] as String? ?? 'pending',
    ),
    failureReason: map['failureReason'] as String?,
    processedAt: map['processedAt'] is fs.Timestamp
        ? (map['processedAt'] as fs.Timestamp).toDate()
        : DateTime.tryParse(map['processedAt']?.toString() ?? '') ??
              DateTime.now(),
  );
}
