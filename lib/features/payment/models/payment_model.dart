import '../../../core/models/enums.dart';

class PaymentRecord {
  final String id;
  final String jobId;
  final double amount;
  final String method; // simulated: 'upi', 'card', 'cash'
  final PaymentStatus status;
  final DateTime processedAt;

  const PaymentRecord({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.method,
    required this.status,
    required this.processedAt,
  });
}
