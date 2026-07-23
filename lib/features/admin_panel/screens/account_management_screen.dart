import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../auth/services/auth_service.dart';
import '../models/account_model.dart';
import '../services/account_service.dart';
import '../services/admin_service.dart';

/// Admin's Account Management Screen — restrict, suspend, or restore any
/// known customer or provider account.
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key});

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  Future<void> _act(ManagedAccount account, AccountStatus target) async {
    final reasonController = TextEditingController();
    final isDestructive = target != AccountStatus.active;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_titleFor(target, account.name)),
        content: isDestructive
            ? TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
              )
            : Text('Restore ${account.name} to an active account?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(backgroundColor: AppColors.error)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_actionLabel(target)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (isDestructive && reasonController.text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('A reason is required.')));
      return;
    }

    final admin = await AuthService.instance.currentUser();
    final adminId = admin?.id ?? 'admin';
    switch (target) {
      case AccountStatus.restricted:
        await AdminService.instance.restrictAccount(
          account.userId,
          adminId: adminId,
          reason: reasonController.text.trim(),
        );
        break;
      case AccountStatus.suspended:
        await AdminService.instance.suspendAccount(
          account.userId,
          adminId: adminId,
          reason: reasonController.text.trim(),
        );
        break;
      case AccountStatus.active:
        await AdminService.instance.restoreAccount(
          account.userId,
          adminId: adminId,
        );
        break;
    }
    if (mounted) setState(() {});
  }

  String _titleFor(AccountStatus target, String name) => switch (target) {
    AccountStatus.restricted => 'Restrict $name?',
    AccountStatus.suspended => 'Suspend $name?',
    AccountStatus.active => 'Restore $name?',
  };

  String _actionLabel(AccountStatus target) => switch (target) {
    AccountStatus.restricted => 'Restrict',
    AccountStatus.suspended => 'Suspend',
    AccountStatus.active => 'Restore',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account management')),
      body: StreamBuilder<void>(
        stream: AccountService.instance.changes,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final accounts = AccountService.instance.allAccounts();
    return accounts.isEmpty
        ? Center(
            child: Text(
              'No accounts to manage yet.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: accounts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = accounts[i];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a.name, style: AppTextStyles.titleMedium),
                                Text(
                                  '${a.role.name} • ${a.email}'
                                  '${a.phone == null ? '' : ' • +91 ${a.phone}'}',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _statusBadge(a.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          if (a.status != AccountStatus.restricted)
                            OutlinedButton(
                              onPressed: () =>
                                  _act(a, AccountStatus.restricted),
                              child: const Text('Restrict'),
                            ),
                          if (a.status != AccountStatus.suspended)
                            OutlinedButton(
                              onPressed: () => _act(a, AccountStatus.suspended),
                              child: const Text('Suspend'),
                            ),
                          if (a.status != AccountStatus.active)
                            FilledButton(
                              onPressed: () => _act(a, AccountStatus.active),
                              child: const Text('Restore'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }

  Widget _statusBadge(AccountStatus status) => switch (status) {
    AccountStatus.active => StatusBadge.success('Active'),
    AccountStatus.restricted => StatusBadge.warning('Restricted'),
    AccountStatus.suspended => StatusBadge.error('Suspended'),
  };
}
