import '../../core/services/firebase_service.dart';

enum AdminAuthStatus {
  /// Waiting on the initial Firebase Auth state / claim check.
  checking,
  signedOut,

  /// Signed in with a real Firebase account, but it does not hold the
  /// `admin` custom claim. Distinct from [signedOut] so the login screen can
  /// explain *why* access was denied instead of just bouncing back silently.
  forbidden,
  signedIn,
}

class AdminAuthState {
  final AdminAuthStatus status;
  final String? email;
  final String? uid;

  const AdminAuthState._(this.status, {this.email, this.uid});

  const AdminAuthState.checking() : this._(AdminAuthStatus.checking);
  const AdminAuthState.signedOut() : this._(AdminAuthStatus.signedOut);
  const AdminAuthState.forbidden(String email)
    : this._(AdminAuthStatus.forbidden, email: email);
  const AdminAuthState.signedIn({required String email, required String uid})
    : this._(AdminAuthStatus.signedIn, email: email, uid: uid);
}

/// Thrown by [AdminAuthService.signIn] when the credentials are valid but the
/// account does not hold the `admin` claim. See `scripts/admin/README.md` for
/// how a claim is granted — it cannot be done from this app.
class AdminAccessDeniedException implements Exception {
  final String message;
  AdminAccessDeniedException(this.message);
  @override
  String toString() => message;
}

/// Firebase Auth sign-in gated on the `admin` custom claim.
///
/// This is deliberately its own service, not a reuse of the mobile app's
/// `AuthService` — that one pulls in device-push registration, session
/// teardown, and account-standing caching that make no sense for an admin
/// session, and some of it (`NotificationService`) is not something this
/// tool should be initializing at all.
///
/// The claim itself can only be granted by `scripts/admin/grant_admin_claim.js`
/// — nothing client-side, including this class, can set it. This class only
/// ever *reads* the claim off an ID token to decide whether to let someone in.
class AdminAuthService {
  AdminAuthService._();
  static final AdminAuthService instance = AdminAuthService._();

  /// Emits the current admin auth state and every change to it. Force-
  /// refreshes the ID token on every emission so a claim granted (or
  /// revoked) while this tab is open is picked up on the next auth event —
  /// notably right after [signIn], and after Firebase's own periodic token
  /// refresh.
  Stream<AdminAuthState> get authStateChanges async* {
    yield const AdminAuthState.checking();
    await for (final user in FirebaseService.instance.auth.authStateChanges()) {
      if (user == null) {
        yield const AdminAuthState.signedOut();
        continue;
      }
      final result = await user.getIdTokenResult(true);
      final isAdmin = result.claims?['admin'] == true;
      if (isAdmin) {
        yield AdminAuthState.signedIn(email: user.email ?? '', uid: user.uid);
      } else {
        yield AdminAuthState.forbidden(user.email ?? '');
      }
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = await FirebaseService.instance.auth
        .signInWithEmailAndPassword(email: email.trim(), password: password);
    final user = credential.user;
    if (user == null) {
      throw AdminAccessDeniedException('Sign-in failed.');
    }
    final result = await user.getIdTokenResult(true);
    if (result.claims?['admin'] != true) {
      // Signed in with valid credentials but no claim — don't leave a
      // non-admin session sitting authenticated against the admin app.
      await FirebaseService.instance.auth.signOut();
      throw AdminAccessDeniedException(
        'This account does not have admin access. Ask an existing admin to '
        'run scripts/admin/grant_admin_claim.js for this email.',
      );
    }
  }

  Future<void> signOut() => FirebaseService.instance.auth.signOut();

  String? get currentEmail => FirebaseService.instance.auth.currentUser?.email;
  String? get currentUid => FirebaseService.instance.auth.currentUser?.uid;
}
