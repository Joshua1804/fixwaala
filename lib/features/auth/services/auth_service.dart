import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/firebase_service.dart';

/// A simulation-mode auth error shaped like [fb_auth.FirebaseAuthException]
/// (same `code`/`message` fields) so [AuthService.friendlyMessage] can
/// handle both without the UI caring which mode is active.
class AuthException implements Exception {
  final String code;
  final String message;
  AuthException(this.code, this.message);

  @override
  String toString() => message;
}

/// Email/password authentication, email verification, password reset, and
/// role-based onboarding/routing (Module 1).
///
/// Firebase-backed when configured; falls back to an in-memory simulation
/// so the full flow — including email verification — stays demonstrable
/// without a real Firebase project.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  static AppUser? _currentUser;
  static final Map<String, AppUser> _userDb = {}; // uid -> AppUser
  static final Map<String, String> _passwords = {}; // uid -> password

  bool get _live => FirebaseService.instance.isInitialized;

  /// Clears all in-memory simulation state. Test-only.
  @visibleForTesting
  void resetForTesting() {
    _currentUser = null;
    _userDb.clear();
    _passwords.clear();
  }

  // ── Registration ──────────────────────────────────────────────────

  /// Creates a new Customer or Provider account and sends a verification
  /// email. Admin accounts can never be created through this method —
  /// admin access is provisioned separately (see [AdminService]) and is
  /// never selectable from the public registration UI.
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    if (role == UserRole.admin) {
      throw ArgumentError(
        'Admin accounts cannot be created through registration.',
      );
    }
    final trimmedEmail = email.trim().toLowerCase();
    final trimmedName = name.trim();

    if (!_live) {
      if (_userDb.values.any((u) => u.email == trimmedEmail)) {
        throw AuthException(
          'email-already-in-use',
          'An account already exists for that email.',
        );
      }
      final now = DateTime.now();
      final id = 'sim_${now.microsecondsSinceEpoch}';
      final user = AppUser(
        id: id,
        email: trimmedEmail,
        role: role,
        name: trimmedName,
        createdAt: now,
        updatedAt: now,
      );
      _userDb[id] = user;
      _passwords[id] = password;
      _currentUser = user;
      return user;
    }

    final auth = FirebaseService.instance.auth;
    final credential = await auth.createUserWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    final fUser = credential.user;
    if (fUser == null) {
      throw Exception('Registration failed. Firebase returned a null user.');
    }
    await fUser.updateDisplayName(trimmedName);
    await fUser.sendEmailVerification();

    final now = DateTime.now();
    final user = AppUser(
      id: fUser.uid,
      email: trimmedEmail,
      role: role,
      name: trimmedName,
      emailVerified: false,
      onboardingComplete: false,
      createdAt: now,
      updatedAt: now,
    );
    await FirebaseService.instance.firestore
        .collection('users')
        .doc(fUser.uid)
        .set(user.toMap());
    _currentUser = user;
    return user;
  }

  // ── Login ────────────────────────────────────────────────────────

  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (!_live) {
      final matches = _userDb.values.where((u) => u.email == trimmedEmail);
      if (matches.isEmpty) {
        throw AuthException(
          'user-not-found',
          'No account found for that email.',
        );
      }
      final user = matches.first;
      if (_passwords[user.id] != password) {
        throw AuthException('wrong-password', 'Incorrect email or password.');
      }
      _currentUser = user;
      return user;
    }

    final auth = FirebaseService.instance.auth;
    final credential = await auth.signInWithEmailAndPassword(
      email: trimmedEmail,
      password: password,
    );
    final fUser = credential.user;
    if (fUser == null) {
      throw Exception('Sign-in failed. Firebase returned a null user.');
    }
    await fUser.reload();
    final verified = auth.currentUser?.emailVerified ?? false;

    final docRef = FirebaseService.instance.firestore
        .collection('users')
        .doc(fUser.uid);
    final doc = await docRef.get();

    AppUser user;
    if (doc.exists) {
      user = AppUser.fromMap(doc.data()!).copyWith(emailVerified: verified);
      if (verified && doc.data()!['emailVerified'] != true) {
        await docRef.update({
          'emailVerified': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
      }
    } else {
      // Defensive fallback — a signed-in Firebase user should always have a
      // matching Firestore doc created at registration time.
      user = AppUser(
        id: fUser.uid,
        email: trimmedEmail,
        role: UserRole.customer,
        emailVerified: verified,
        createdAt: DateTime.now(),
      );
      await docRef.set(user.toMap());
    }
    _currentUser = user;
    return user;
  }

  // ── Email verification ──────────────────────────────────────────

  Future<void> sendEmailVerification() async {
    if (!_live) return; // Use simulateVerifyEmail() in demo mode instead.
    final fUser = FirebaseService.instance.auth.currentUser;
    if (fUser == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }
    await fUser.sendEmailVerification();
  }

  /// Re-checks verification status with Firebase and persists it once true.
  Future<bool> reloadAndCheckEmailVerified() async {
    if (!_live) return _currentUser?.emailVerified ?? false;

    final auth = FirebaseService.instance.auth;
    final fUser = auth.currentUser;
    if (fUser == null) return false;
    await fUser.reload();
    final verified = auth.currentUser?.emailVerified ?? false;

    if (verified && _currentUser != null && !_currentUser!.emailVerified) {
      final updated = _currentUser!.copyWith(emailVerified: true);
      await FirebaseService.instance.firestore
          .collection('users')
          .doc(updated.id)
          .update({
            'emailVerified': true,
            'updatedAt': DateTime.now().toIso8601String(),
          });
      _currentUser = updated;
    }
    return verified;
  }

  /// Demo-only: marks the current session's email as verified without a
  /// real inbox, since simulation mode cannot send real emails.
  void simulateVerifyEmail() {
    if (_live || _currentUser == null) return;
    final updated = _currentUser!.copyWith(emailVerified: true);
    _userDb[updated.id] = updated;
    _currentUser = updated;
  }

  // ── Password reset ──────────────────────────────────────────────

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmed = email.trim().toLowerCase();
    if (!_live) {
      if (!_userDb.values.any((u) => u.email == trimmed)) {
        throw AuthException(
          'user-not-found',
          'No account found for that email.',
        );
      }
      return; // Simulated — nothing to actually send.
    }
    await FirebaseService.instance.auth.sendPasswordResetEmail(email: trimmed);
  }

  // ── Onboarding ───────────────────────────────────────────────────

  Future<void> completeOnboarding({
    String? phone,
    CustomerProfile? customerProfile,
    ProviderProfile? providerProfile,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw StateError('No signed-in user to onboard.');
    }
    final updated = current.copyWith(
      phone: phone,
      customerProfile: customerProfile,
      providerProfile: providerProfile,
      onboardingComplete: true,
      updatedAt: DateTime.now(),
    );
    _currentUser = updated;

    if (!_live) {
      _userDb[updated.id] = updated;
      return;
    }

    await FirebaseService.instance.firestore
        .collection('users')
        .doc(updated.id)
        .update({
          if (phone != null) 'phone': phone,
          if (customerProfile != null)
            'customerProfile': customerProfile.toMap(),
          if (providerProfile != null)
            'providerProfile': providerProfile.toMap(),
          'onboardingComplete': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  // ── Session ──────────────────────────────────────────────────────

  Future<AppUser?> currentUser() async {
    if (!_live) return _currentUser;

    final fUser = FirebaseService.instance.auth.currentUser;
    if (fUser == null) {
      _currentUser = null;
      return null;
    }
    if (_currentUser != null && _currentUser!.id == fUser.uid) {
      return _currentUser;
    }

    final doc = await FirebaseService.instance.firestore
        .collection('users')
        .doc(fUser.uid)
        .get();

    if (doc.exists) {
      _currentUser = AppUser.fromMap(
        doc.data()!,
      ).copyWith(emailVerified: fUser.emailVerified);
    } else {
      _currentUser = null;
    }
    return _currentUser;
  }

  Future<void> signOut() async {
    _currentUser = null;
    if (_live) {
      await FirebaseService.instance.auth.signOut();
    }
  }

  /// Where a user should land right now — used by the splash screen on
  /// cold start and after login/verification/onboarding, so there is one
  /// single source of truth for role-based routing (fixes customers and
  /// providers ending up on the same page).
  Future<String> resolveInitialRoute() async {
    final user = await currentUser();
    if (user == null) return RouteNames.roleSelection;
    if (user.role == UserRole.admin) return RouteNames.adminDashboard;
    if (!user.emailVerified) return RouteNames.emailVerification;
    if (!user.onboardingComplete) {
      return user.role == UserRole.provider
          ? RouteNames.providerOnboarding
          : RouteNames.customerOnboarding;
    }
    return user.role == UserRole.provider
        ? RouteNames.providerHome
        : RouteNames.customerHome;
  }

  /// All users seen during this app session (simulation mode only).
  ///
  /// Used by the Admin Panel's Account Management screen so admins have
  /// real accounts to act on. Returns an empty list once Firebase is
  /// configured — that path should query Firestore's `users` collection
  /// directly instead.
  List<AppUser> knownDemoUsers() {
    if (_live) return const [];
    return _userDb.values.toList();
  }

  /// Maps a raw auth error (Firebase or simulated) to user-facing text.
  static String friendlyMessage(Object error) {
    String code;
    String? fallback;
    if (error is fb_auth.FirebaseAuthException) {
      code = error.code;
      fallback = error.message;
    } else if (error is AuthException) {
      code = error.code;
      fallback = error.message;
    } else {
      return error.toString();
    }
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password (at least 6 characters).';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'requires-recent-login':
        return 'Please sign in again to continue.';
      default:
        return fallback ?? 'Something went wrong. Please try again.';
    }
  }
}
