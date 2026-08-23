import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_facing_exception.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/account_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/provider_directory_service.dart';

/// A simulation-mode auth error shaped like [fb_auth.FirebaseAuthException]
/// (same `code`/`message` fields) so [AuthService.friendlyMessage] can
/// handle both without the UI caring which mode is active.
class AuthException implements UserFacingException {
  final String code;
  @override
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
  /// email. Those are the only two roles the app knows about — administrator
  /// access is a Firebase custom claim granted out of band and is used solely
  /// by the separate admin website.
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
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
    _cacheStanding(user);
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
          'phone': ?phone,
          if (customerProfile != null)
            'customerProfile': customerProfile.toMap(),
          if (providerProfile != null)
            'providerProfile': providerProfile.toMap(),
          'onboardingComplete': true,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  // ── Profile editing ──────────────────────────────────────────────

  /// Persists the editable fields of the signed-in user's own profile.
  ///
  /// The profile tab previously called `copyWith(...)` and discarded the
  /// result, so "Profile updated successfully" was shown for a write that
  /// never happened. Callers must await this and only report success once it
  /// completes.
  Future<AppUser> updateProfile({
    String? name,
    String? phone,
    String? photoUrl,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }

    final trimmedName = name?.trim();
    final trimmedPhone = phone?.trim();

    final updated = current.copyWith(
      name: trimmedName,
      phone: trimmedPhone,
      photoUrl: photoUrl,
      updatedAt: DateTime.now(),
    );
    _currentUser = updated;
    _userChanges.add(updated);

    if (!_live) {
      _userDb[updated.id] = updated;
      return updated;
    }

    await FirebaseService.instance.firestore
        .collection('users')
        .doc(updated.id)
        .update({
          'name': ?trimmedName,
          'phone': ?trimmedPhone,
          'photoUrl': ?photoUrl,
          'updatedAt': DateTime.now().toIso8601String(),
        });
    return updated;
  }

  // ── Email change ────────────────────────────────────────────────

  /// Changes the signed-in user's email. Requires re-entering the current
  /// password (Firebase requires recent re-authentication before an email
  /// change; simulation mode mirrors that requirement for consistency).
  ///
  /// Live mode sends a verification link to [newEmail] and does **not**
  /// flip `users/{uid}.email` yet — Firebase only updates its own record
  /// once the link is clicked, and this app has no server-side listener for
  /// that. `login()` already reconciles `emailVerified` lazily against
  /// Firebase's live value on next sign-in; the same reconciliation needs to
  /// cover `email` once this ships (tracked as follow-up, not blocking this
  /// change — see docs/superpowers/specs/2026-08-18-punch-list-design.md).
  Future<void> changeEmail({
    required String currentPassword,
    required String newEmail,
  }) async {
    final trimmedEmail = newEmail.trim().toLowerCase();
    final current = _currentUser;
    if (current == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }

    if (!_live) {
      if (_passwords[current.id] != currentPassword) {
        throw AuthException('wrong-password', 'Incorrect password.');
      }
      final withNewEmail = AppUser(
        id: current.id,
        email: trimmedEmail,
        role: current.role,
        createdAt: current.createdAt,
        phone: current.phone,
        name: current.name,
        photoUrl: current.photoUrl,
        emailVerified: current.emailVerified,
        onboardingComplete: current.onboardingComplete,
        accountStatus: current.accountStatus,
        isVerified: current.isVerified,
        customerProfile: current.customerProfile,
        providerProfile: current.providerProfile,
        updatedAt: DateTime.now(),
      );
      _userDb[withNewEmail.id] = withNewEmail;
      _currentUser = withNewEmail;
      _userChanges.add(withNewEmail);
      return;
    }

    final auth = FirebaseService.instance.auth;
    final fUser = auth.currentUser;
    if (fUser == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }
    final credential = fb_auth.EmailAuthProvider.credential(
      email: current.email,
      password: currentPassword,
    );
    await fUser.reauthenticateWithCredential(credential);
    await fUser.verifyBeforeUpdateEmail(trimmedEmail);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final current = _currentUser;
    if (current == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }

    if (!_live) {
      if (_passwords[current.id] != currentPassword) {
        throw AuthException('wrong-password', 'Incorrect password.');
      }
      _passwords[current.id] = newPassword;
      return;
    }

    final auth = FirebaseService.instance.auth;
    final fUser = auth.currentUser;
    if (fUser == null) {
      throw AuthException('no-current-user', 'You must be signed in.');
    }
    final credential = fb_auth.EmailAuthProvider.credential(
      email: current.email,
      password: currentPassword,
    );
    await fUser.reauthenticateWithCredential(credential);
    await fUser.updatePassword(newPassword);
  }

  // ── Provider presence ────────────────────────────────────────────

  /// Overwrites the current (provider) user's `providerProfile` — used by
  /// [ProviderPresenceService] to persist online status and live location
  /// without going through the full onboarding flow.
  Future<void> updateProviderProfile(ProviderProfile profile) async {
    final current = _currentUser;
    if (current == null) return;
    final updated = current.copyWith(
      providerProfile: profile,
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
          'providerProfile': profile.toMap(),
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  // ── Session ──────────────────────────────────────────────────────

  /// Broadcasts local mutations (profile edits, verification, onboarding) so
  /// [currentUserStream] reflects them immediately rather than waiting for a
  /// Firestore round trip — and so simulation mode has a change signal at all.
  static final StreamController<AppUser?> _userChanges =
      StreamController<AppUser?>.broadcast();

  /// The signed-in user, as a stream.
  ///
  /// Replaces `FutureBuilder(future: currentUser())` built inside `build()`,
  /// which created a new future on every rebuild — re-firing a billable
  /// Firestore read and flashing the loading state each time. Emits `null`
  /// when signed out, so callers can drive their whole tree from one
  /// subscription.
  Stream<AppUser?> get currentUserStream {
    if (!_live) {
      // Simulation mode has no auth or document streams to listen to; the
      // in-memory user only changes when this service changes it.
      return _userChanges.stream.map((user) => user ?? _currentUser);
    }

    return FirebaseService.instance.auth.authStateChanges().asyncExpand((
      fUser,
    ) {
      if (fUser == null) {
        _currentUser = null;
        AccountService.instance.clear();
        return Stream<AppUser?>.value(null);
      }

      // Firestore emits snapshots optimistically for local pending writes, so
      // an edit made through this service appears here before the server
      // acknowledges it — no separate merge with [_userChanges] needed.
      return FirebaseService.instance.firestore
          .collection('users')
          .doc(fUser.uid)
          .snapshots()
          .map<AppUser?>((doc) {
            if (!doc.exists || doc.data() == null) return null;
            final user = AppUser.fromMap(
              doc.data()!,
            ).copyWith(emailVerified: fUser.emailVerified);
            _currentUser = user;
            _cacheStanding(user);
            // Keeps `providerPublicProfiles/{uid}` in step with the account.
            // Driven from the owner's own listener because `users/{uid}` is
            // owner-readable — nobody else could observe the change. No-ops
            // for customers and when the projection has not changed.
            unawaited(ProviderDirectoryService.instance.publishSelf(user));
            return user;
          });
    });
  }

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
      _cacheStanding(_currentUser!);
    } else {
      _currentUser = null;
    }
    return _currentUser;
  }

  /// Mirrors the standing carried on a user document into [AccountService],
  /// which is what the service layer consults before job, payment, and rating
  /// actions. The admin website owns the field; the app only observes it.
  void _cacheStanding(AppUser user) {
    AccountService.instance.cacheStatus(user.id, user.accountStatus);

    // Register for push once per session, whether the user just signed in or
    // returned to an existing session on relaunch. A token registered before
    // auth resolves cannot be attributed to anybody.
    if (_pushRegisteredFor != user.id) {
      _pushRegisteredFor = user.id;
      unawaited(
        NotificationService.instance.registerDevice(
          userId: user.id,
          role: user.role,
        ),
      );
    }
  }

  static String? _pushRegisteredFor;

  /// Looks up any user by id — used to show a provider's public profile to
  /// a customer reviewing candidates, distinct from [currentUser] which
  /// only ever resolves the signed-in session's own account.
  Future<AppUser?> getUserById(String userId) async {
    if (!_live) return _userDb[userId];

    final doc = await FirebaseService.instance.firestore
        .collection('users')
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  Future<void> signOut() async {
    _currentUser = null;
    _pushRegisteredFor = null;
    AccountService.instance.clear();
    ProviderDirectoryService.instance.endSession();
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
  /// Returns an empty list once Firebase is configured. Kept for simulation
  /// -mode fixtures only — no production screen depends on it.
  @visibleForTesting
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
