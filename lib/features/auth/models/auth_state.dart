import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';

enum AuthStage { idle, sendingOtp, awaitingOtp, verifying, authenticated, failed }

class AuthState {
  final AuthStage stage;
  final UserRole? selectedRole;
  final String? phone;
  final String? verificationId;
  final AppUser? user;
  final String? errorMessage;

  const AuthState({
    this.stage = AuthStage.idle,
    this.selectedRole,
    this.phone,
    this.verificationId,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStage? stage,
    UserRole? selectedRole,
    String? phone,
    String? verificationId,
    AppUser? user,
    String? errorMessage,
  }) {
    return AuthState(
      stage: stage ?? this.stage,
      selectedRole: selectedRole ?? this.selectedRole,
      phone: phone ?? this.phone,
      verificationId: verificationId ?? this.verificationId,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}
