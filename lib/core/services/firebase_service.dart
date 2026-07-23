import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Central handle for Firebase-backed services (Auth, Firestore).
class FirebaseService {
  FirebaseService._();
  static final FirebaseService instance = FirebaseService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey == 'placeholder-apiKey') {
        debugPrint(
          'Firebase is using placeholder options. Running in simulation mode.',
        );
        _isInitialized = false;
        return;
      }

      await Firebase.initializeApp(options: options);
      _isInitialized = true;
      debugPrint('Firebase initialized successfully.');
    } catch (e) {
      debugPrint(
        'Firebase initialization failed: $e. Running in simulation mode.',
      );
      _isInitialized = false;
    }
  }

  FirebaseAuth get auth {
    if (!_isInitialized) {
      throw StateError('Firebase Auth is not initialized/configured.');
    }
    return FirebaseAuth.instance;
  }

  FirebaseFirestore get firestore {
    if (!_isInitialized) {
      throw StateError('Firebase Firestore is not initialized/configured.');
    }
    return FirebaseFirestore.instance;
  }
}
