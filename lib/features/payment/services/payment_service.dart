import '../../../core/models/enums.dart';
import '../models/payment_model.dart';

/// Simulated payment — no real money moves. Records a Firestore document
/// so the rest of the app can react as if a payment happened.
class PaymentService {
  PaymentService._();
  static final PaymentService instance = PaymentService._();

  Future<PaymentRecord> simulate({
    required String jobId,
    required double amount,
    required String method,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    final now = DateTime.now();
    return PaymentRecord(
      id: 'pay-${now.microsecondsSinceEpoch}',
      jobId: jobId,
      amount: amount,
      method: method,
      status: PaymentStatus.success,
      processedAt: now,
    );
  }
}
