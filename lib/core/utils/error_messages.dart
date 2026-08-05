import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;

import '../models/user_facing_exception.dart';

/// Turns any thrown object into something a user can act on.
///
/// Before this existed, seven screens rendered `Text('$e')` directly, so users
/// saw strings like `Bad state: No element` or
/// `JobTransitionException: Accepting the job is not available while the job is
/// en route`. The domain exceptions already carry human-readable messages —
/// the problem was the raw ones leaking through alongside them.
///
/// [AuthService.friendlyMessage] handles auth codes specifically and should
/// still be preferred inside the auth flows; this covers everywhere else.
class ErrorMessages {
  ErrorMessages._();

  /// A short sentence suitable for a snackbar or an inline error state.
  static String friendly(Object? error) {
    if (error == null) return 'Something went wrong. Please try again.';

    // Already written for a user — JobTransitionException,
    // DuplicateRatingException, AccountRestrictedException, AuthException.
    if (error is UserFacingException) return error.message;

    if (error is FirebaseException) return _firestore(error);
    if (error is TimeoutException) {
      return 'That took too long. Check your connection and try again.';
    }
    if (error is SocketException || error is HttpException) {
      return 'No internet connection. Check your network and try again.';
    }
    if (error is FormatException) {
      return 'We received an unexpected response. Please try again.';
    }
    if (error is ArgumentError) {
      // Services use ArgumentError for validation the user can fix, e.g.
      // "Please describe what happened."
      final message = error.message;
      if (message is String && message.trim().isNotEmpty) return message;
      return 'Please check what you entered and try again.';
    }
    if (error is StateError) {
      return 'That item is no longer available.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String _firestore(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
      case 'deadline-exceeded':
        return 'Cannot reach the server right now. Check your connection.';
      case 'not-found':
        return 'That item no longer exists.';
      case 'already-exists':
        return 'That already exists.';
      case 'resource-exhausted':
        return 'Too many requests. Please wait a moment and try again.';
      case 'unauthenticated':
        return 'Your session expired. Please sign in again.';
      case 'cancelled':
        return 'That request was cancelled.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
