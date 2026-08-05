import 'package:flutter/foundation.dart';

import '../models/enums.dart';
import '../models/user_facing_exception.dart';

/// Thrown when a restricted or suspended account attempts an action that
/// requires active standing (accepting jobs, paying, rating, etc.).
class AccountRestrictedException implements UserFacingException {
  @override
  final String message;
  AccountRestrictedException(this.message);

  @override
  String toString() => message;
}

/// Read-only account-standing enforcement.
///
/// Moderation itself happens in the admin website, which writes
/// `users/{uid}.accountStatus`. The mobile app never mutates that field — it
/// only caches what it read for the signed-in user and refuses actions that a
/// non-active account must not perform.
///
/// This is a **UX guard, not the enforcement boundary**. Real enforcement lives
/// in `firestore.rules`; a client that skipped this check would still be denied
/// server-side. Unknown user ids are therefore treated as active rather than
/// blocked, so a missing cache entry can never lock a legitimate user out.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final Map<String, AccountStatus> _status = {};
  final Map<String, String> _reason = {};

  @visibleForTesting
  void resetForTesting() {
    _status.clear();
    _reason.clear();
  }

  /// Records the standing carried on a user document. Called whenever the app
  /// loads a user, so [assertActive] can answer without another read.
  void cacheStatus(String userId, AccountStatus status, {String? reason}) {
    _status[userId] = status;
    if (reason == null) {
      _reason.remove(userId);
    } else {
      _reason[userId] = reason;
    }
  }

  /// Drops all cached standing. Called on sign-out so the next account never
  /// inherits the previous one's state.
  void clear() {
    _status.clear();
    _reason.clear();
  }

  AccountStatus statusOf(String userId) =>
      _status[userId] ?? AccountStatus.active;

  String? reasonFor(String userId) => _reason[userId];

  /// Throws [AccountRestrictedException] if [userId]'s account is currently
  /// restricted or suspended. Call this at the top of any service action that
  /// a non-active account must not be able to perform.
  void assertActive(String userId) {
    final status = statusOf(userId);
    if (status == AccountStatus.suspended) {
      throw AccountRestrictedException(
        'Your account has been suspended and cannot perform this action.',
      );
    }
    if (status == AccountStatus.restricted) {
      throw AccountRestrictedException(
        'Your account is restricted and cannot perform this action.',
      );
    }
  }
}
