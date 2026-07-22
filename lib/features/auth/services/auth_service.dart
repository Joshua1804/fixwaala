import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/firebase_service.dart';

/// Handles OTP send/verify, session persistence, role lookup and onboarding routing.
///
/// Backed by Firebase Auth phone provider once wired.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // In-memory simulation state
  static AppUser? _currentUser;
  static final Map<String, AppUser> _userDb = {}; // userId -> AppUser
  static final Set<String> _onboardedUsers = {}; // userId

  Future<String> sendOtp(String phone) async {
    if (!FirebaseService.instance.isInitialized) {
      // Simulated OTP send — encode phone into verification ID
      return 'mock_phone:$phone';
    }

    final completer = Completer<String>();
    try {
      await FirebaseService.instance.auth.verifyPhoneNumber(
        phoneNumber: '+91$phone',
        verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
          // Auto-retrieval completed: can automatically proceed if needed
        },
        verificationFailed: (fb_auth.FirebaseAuthException e) {
          completer.completeError(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Handle auto retrieval timeout
        },
        timeout: const Duration(seconds: 30),
      );
    } catch (e) {
      completer.completeError(e);
    }
    return completer.future;
  }

  Future<AppUser> verifyOtp({
    required String verificationId,
    required String smsCode,
    required UserRole role,
  }) async {
    if (!FirebaseService.instance.isInitialized) {
      // Simulated OTP verification
      String cleanPhone = '9876543210';
      if (verificationId.startsWith('mock_phone:')) {
        cleanPhone = verificationId.substring('mock_phone:'.length);
      }

      // Try to retrieve existing user if they have already registered
      final userId = 'mock_${role.name}_$cleanPhone';
      AppUser user;
      if (_userDb.containsKey(userId)) {
        user = _userDb[userId]!;
      } else {
        user = AppUser(
          id: userId,
          phone: cleanPhone,
          role: role,
          createdAt: DateTime.now(),
        );
        _userDb[userId] = user;
      }

      _currentUser = user;
      return user;
    }

    // Real Firebase Auth Integration
    final auth = FirebaseService.instance.auth;
    final credential = fb_auth.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    final userCredential = await auth.signInWithCredential(credential);
    final fUser = userCredential.user;
    if (fUser == null) {
      throw Exception('Sign-in failed. Firebase returned a null user.');
    }

    // Check Cloud Firestore for registered account
    final firestore = FirebaseService.instance.firestore;
    final docRef = firestore.collection('users').doc(fUser.uid);
    final doc = await docRef.get();

    AppUser user;
    final cleanPhone = fUser.phoneNumber ?? '';

    if (doc.exists) {
      final data = doc.data()!;
      user = AppUser(
        id: fUser.uid,
        phone: cleanPhone,
        role: UserRole.values.byName(data['role'] as String? ?? role.name),
        name: data['name'] as String?,
        email: data['email'] as String?,
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'] as String)
            : DateTime.now(),
      );
    } else {
      // New user: register in Firestore with role
      user = AppUser(
        id: fUser.uid,
        phone: cleanPhone,
        role: role,
        createdAt: DateTime.now(),
      );
      await docRef.set({
        'id': user.id,
        'phone': user.phone,
        'role': user.role.name,
        'createdAt': user.createdAt.toIso8601String(),
      });
    }

    _currentUser = user;
    return user;
  }

  Future<AppUser?> currentUser() async {
    if (!FirebaseService.instance.isInitialized) {
      return _currentUser;
    }

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
      final data = doc.data()!;
      _currentUser = AppUser(
        id: fUser.uid,
        phone: fUser.phoneNumber ?? '',
        role: UserRole.values.byName(data['role'] as String? ?? UserRole.customer.name),
        name: data['name'] as String?,
        email: data['email'] as String?,
        createdAt: data['createdAt'] != null
            ? DateTime.parse(data['createdAt'] as String)
            : DateTime.now(),
      );
    } else {
      _currentUser = null;
    }

    return _currentUser;
  }

  Future<bool> isOnboarded(String userId, UserRole role) async {
    if (!FirebaseService.instance.isInitialized) {
      final user = _userDb[userId];
      if (user != null && user.name != null && user.name!.isNotEmpty) {
        _onboardedUsers.add(userId);
        return true;
      }
      return _onboardedUsers.contains(userId);
    }

    final doc = await FirebaseService.instance.firestore
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists) {
      final data = doc.data()!;
      final name = data['name'] as String?;
      return name != null && name.trim().isNotEmpty;
    }
    return false;
  }

  /// Mark a user as onboarded manually
  void markOnboarded(String userId) {
    _onboardedUsers.add(userId);
  }

  /// Update the current user's profile and mark them as onboarded
  Future<void> updateProfile({required String name, String? email}) async {
    if (_currentUser == null) return;

    final updated = AppUser(
      id: _currentUser!.id,
      phone: _currentUser!.phone,
      role: _currentUser!.role,
      name: name,
      email: email,
      createdAt: _currentUser!.createdAt,
    );
    _currentUser = updated;

    if (!FirebaseService.instance.isInitialized) {
      _userDb[updated.id] = updated;
      _onboardedUsers.add(updated.id);
      return;
    }

    await FirebaseService.instance.firestore
        .collection('users')
        .doc(updated.id)
        .update({
      'name': name,
      'email': email,
    });
  }

  Future<void> signOut() async {
    _currentUser = null;
    if (FirebaseService.instance.isInitialized) {
      await FirebaseService.instance.auth.signOut();
    }
  }
}


