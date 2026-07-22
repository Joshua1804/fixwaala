import '../../../core/models/enums.dart';

class ProviderVerification {
  final String providerId;
  final String maskedAadhaar;
  final bool aadhaarApiVerified;
  final String? selfieUrl;
  final bool livenessPassed;
  final bool faceMatchPassed;
  final VerificationStatus status;
  final String? adminNote;
  final DateTime updatedAt;

  const ProviderVerification({
    required this.providerId,
    required this.maskedAadhaar,
    required this.aadhaarApiVerified,
    required this.livenessPassed,
    required this.faceMatchPassed,
    required this.status,
    required this.updatedAt,
    this.selfieUrl,
    this.adminNote,
  });
}
