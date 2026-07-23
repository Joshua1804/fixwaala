import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/models/enums.dart';
import '../../auth/services/auth_service.dart';
import '../models/account_model.dart';

/// Thrown when a restricted or suspended account attempts an action that
/// requires active standing (accepting jobs, paying, rating, etc.).
class AccountRestrictedException implements Exception {
  final String message;
  AccountRestrictedException(this.message);

  @override
  String toString() => message;
}

/// Account Management (Module 12) — restrict, suspend, or restore accounts.
///
/// Moderation status is tracked here, independent of [AuthService], and
/// merged with known users at query time so the Admin Panel can act on
/// whoever has signed up during the session.
class AccountService {
  AccountService._();
  static final AccountService instance = AccountService._();

  final Map<String, AccountStatus> _status = {};
  final Map<String, String> _reason = {};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  /// Emits whenever any account's status changes — admin screens listen to
  /// this to stay live without needing a manual refresh.
  Stream<void> get changes => _changes.stream;

  @visibleForTesting
  void resetForTesting() {
    _status.clear();
    _reason.clear();
  }

  /// Throws [AccountRestrictedException] if [userId]'s account is currently
  /// restricted or suspended. Call this at the top of any service action
  /// that a non-active account must not be able to perform.
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

  List<ManagedAccount> allAccounts() {
    final users = AuthService.instance.knownDemoUsers();
    final accounts = users
        .where((u) => u.role != UserRole.admin)
        .map(
          (u) => ManagedAccount(
            userId: u.id,
            name: (u.name == null || u.name!.isEmpty)
                ? 'Unnamed user'
                : u.name!,
            email: u.email,
            phone: u.phone,
            role: u.role,
            status: _status[u.id] ?? AccountStatus.active,
            restrictionReason: _reason[u.id],
          ),
        )
        .toList();
    accounts.sort((a, b) => a.name.compareTo(b.name));
    return accounts;
  }

  int countByStatus(AccountStatus status) =>
      allAccounts().where((a) => a.status == status).length;

  AccountStatus statusOf(String userId) =>
      _status[userId] ?? AccountStatus.active;

  Future<void> restrict(String userId, {required String reason}) async {
    _status[userId] = AccountStatus.restricted;
    _reason[userId] = reason;
    _changes.add(null);
  }

  Future<void> suspend(String userId, {required String reason}) async {
    _status[userId] = AccountStatus.suspended;
    _reason[userId] = reason;
    _changes.add(null);
  }

  Future<void> restore(String userId) async {
    _status[userId] = AccountStatus.active;
    _reason.remove(userId);
    _changes.add(null);
  }
}
