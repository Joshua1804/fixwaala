import '../../../core/services/firebase_service.dart';
import '../../../core/models/enums.dart';
import '../models/verification_model.dart';

/// Sandbox Aadhaar + selfie verification integration.
///
/// For the college demo we call sandbox endpoints; no real KYC data is stored.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  Future<bool> verifyAadhaarSandbox({
    required String aadhaarNumber,
    required String fullName,
  }) async {
    // TODO: POST to sandbox Aadhaar demo API, parse response.
    await Future.delayed(const Duration(seconds: 1));
    return true;
  }

  Future<String> uploadSelfie(String localPath) async {
    // TODO: Firebase Storage upload; return download URL.
    return 'https://placeholder/selfie.jpg';
  }

  Future<({bool liveness, bool faceMatch})> runSelfieChecks({
    required String selfieUrl,
    required String? referenceImageUrl,
  }) async {
    // TODO: call face-match / liveness API.
    return (liveness: true, faceMatch: true);
  }

  Future<void> submitForAdminReview(ProviderVerification v) async {
    if (!FirebaseService.instance.isInitialized) return;

    // Write verification submission to Firestore user document
    await FirebaseService.instance.firestore
        .collection('users')
        .doc(v.providerId)
        .update({
          'verificationStatus': VerificationStatus.pending.name,
          'aadhaarNumber': v.maskedAadhaar,
          'selfieUrl': v.selfieUrl,
        });
  }

  Future<VerificationStatus> status(String providerId) async {
    if (!FirebaseService.instance.isInitialized) {
      return VerificationStatus.pending;
    }

    try {
      final doc = await FirebaseService.instance.firestore
          .collection('users')
          .doc(providerId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        final statusName = data['verificationStatus'] as String?;
        if (statusName != null) {
          return VerificationStatus.values.byName(statusName);
        }
      }
    } catch (_) {}
    return VerificationStatus.pending;
  }
}
