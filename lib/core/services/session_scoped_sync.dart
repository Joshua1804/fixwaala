import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_service.dart';

/// Keeps a set of Firestore listeners bound to whoever is currently signed in.
///
/// Every collection listener in the app used to be an unfiltered
/// `collection.snapshots()` opened once at startup, so each device downloaded
/// and held **every** job, payment, and rating on the platform — a privacy
/// leak, an unbounded memory cost, and an O(users²) Firestore bill.
///
/// Scoping alone is not enough: `initialize()` runs from `main()` before auth
/// resolves, so a query needs a uid that does not exist yet, and it must be
/// rebuilt when the user changes. This owns that lifecycle:
///
/// * waits for auth before subscribing,
/// * tears the listeners down and clears the cache on sign-out, so one
///   account's data can never be visible to the next,
/// * re-subscribes when a different user signs in.
///
/// A user may match a document by more than one field (a job references both
/// `customerId` and `providerId`), and Firestore cannot OR across fields in a
/// single indexable query — hence [queriesForUser] returning a list.
class SessionScopedSync {
  /// Identifies this sync in error logs.
  final String debugName;

  /// The queries to watch for [uid]. Usually one per field the user can
  /// appear under. Returning an empty list means "this user sees nothing".
  final List<Query<Map<String, dynamic>>> Function(String uid) queriesForUser;

  /// Applies one changed document to the local cache.
  final void Function(DocumentChange<Map<String, dynamic>> change) onChange;

  /// Drops every cached document. Called on sign-out and before rebinding.
  final VoidCallback onClear;

  SessionScopedSync({
    required this.debugName,
    required this.queriesForUser,
    required this.onChange,
    required this.onClear,
  });

  StreamSubscription<Object?>? _authSub;
  final List<StreamSubscription<Object?>> _dataSubs = [];
  String? _boundUid;

  /// Begins following the auth state. Safe to call more than once.
  Future<void> start() async {
    if (!FirebaseService.instance.isInitialized) return;
    await _authSub?.cancel();
    _authSub = FirebaseService.instance.auth.authStateChanges().listen((user) {
      _bind(user?.uid);
    });
  }

  void _bind(String? uid) {
    if (uid == _boundUid) return;
    _boundUid = uid;
    _cancelData();
    onClear();
    if (uid == null) return;

    for (final query in queriesForUser(uid)) {
      _dataSubs.add(
        query.snapshots().listen(
          (snapshot) {
            for (final change in snapshot.docChanges) {
              if (change.doc.data() == null) continue;
              onChange(change);
            }
          },
          onError: (Object error) {
            // Every listener needs this. Two of the three previously had no
            // error handler at all, so a permission-denied silently froze
            // earnings and ratings at their last value with no signal.
            debugPrint('[$debugName] Firestore listener error: $error');
          },
        ),
      );
    }
  }

  void _cancelData() {
    for (final sub in _dataSubs) {
      sub.cancel();
    }
    _dataSubs.clear();
  }

  /// Tears everything down and clears the cache — call on sign-out.
  Future<void> stop() async {
    await _authSub?.cancel();
    _authSub = null;
    _cancelData();
    _boundUid = null;
    onClear();
  }
}
