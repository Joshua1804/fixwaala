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

  /// Why the app fell back to simulation mode, if it did.
  ///
  /// The fallback used to announce itself with a `debugPrint` and nothing
  /// else. A misconfigured build therefore launched, looked entirely healthy,
  /// and silently persisted **nothing** — every ticket, job, and payment lost
  /// on restart, with the only warning in a console nobody was watching.
  /// [SimulationModeBanner] surfaces this in the UI instead.
  String? _simulationReason;
  String? get simulationReason => _simulationReason;

  bool get isSimulated => !_isInitialized;

  Future<void> initialize() async {
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      if (options.apiKey == 'placeholder-apiKey') {
        _isInitialized = false;
        _simulationReason =
            'Firebase is not configured for this build — run '
            '`flutterfire configure`.';
        debugPrint('[FirebaseService] $_simulationReason');
        return;
      }

      await Firebase.initializeApp(options: options);
      _isInitialized = true;
      _simulationReason = null;
      debugPrint('[FirebaseService] Firebase initialized successfully.');
    } catch (e) {
      _isInitialized = false;
      _simulationReason = 'Firebase failed to start: $e';
      debugPrint('[FirebaseService] $_simulationReason');
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
