import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatting.dart';
import '../../core/admin_auth_service.dart';
import '../../widgets/admin_data_table.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import 'services/admin_directory_service.dart';

/// Who currently holds the `admin` custom claim.
///
/// This screen is read-only by design — see `admins/{uid}` in
/// `firestore.rules`. Granting access is a script an operator runs locally
/// with a service-account key, not a button in a browser, because the claim
/// can only be set by the Firebase Admin SDK. The commands below are
/// copyable so that boundary costs as little friction as possible.
class AdminAdminsScreen extends StatelessWidget {
  const AdminAdminsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Admins',
      subtitle: 'Accounts with admin access to this website.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GrantAccessPanel(),
          const SizedBox(height: AppSpacing.xxl),
          Text('Current admins', style: AppTextStyles.titleMedium),
          const SizedBox(height: AppSpacing.md),
          StreamBuilder<List<AdminDirectoryEntry>>(
            stream: AdminDirectoryService.instance.watch(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AdminLoadingView();
              }
              if (snapshot.hasError) {
                return AdminErrorView(error: snapshot.error!);
              }
              final admins = snapshot.data ?? [];
              if (admins.isEmpty) {
                return const AdminEmptyView(
                  title: 'No admins yet',
                  message:
                      'Grant the first one with the command above, then '
                      'sign in with that account.',
                  icon: Icons.admin_panel_settings_outlined,
                );
              }
              return AdminTableCard(
                columns: const [
                  DataColumn(label: Text('Email')),
                  DataColumn(label: Text('Granted')),
                  DataColumn(label: Text('Granted by')),
                  DataColumn(label: Text('You')),
                ],
                rows: admins.map((admin) {
                  final isSelf =
                      admin.uid == AdminAuthService.instance.currentUid;
                  return DataRow(
                    cells: [
                      DataCell(Text(admin.email)),
                      DataCell(
                        Text(
                          admin.grantedAt != null
                              ? RelativeTime.format(admin.grantedAt!)
                              : '—',
                        ),
                      ),
                      DataCell(Text(admin.grantedBy ?? '—')),
                      DataCell(
                        isSelf
                            ? const Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.success,
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GrantAccessPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terminal_rounded, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: AppSpacing.sm),
              Text('Grant or revoke access', style: AppTextStyles.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Run from the repo root, with a service-account key set up per '
            'scripts/admin/README.md. The affected account must sign out '
            'and back in for the change to take effect.',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _CommandLine(command: 'node scripts/admin/grant_admin_claim.js grant <email>'),
          const SizedBox(height: AppSpacing.sm),
          _CommandLine(command: 'node scripts/admin/grant_admin_claim.js revoke <email>'),
        ],
      ),
    );
  }
}

class _CommandLine extends StatelessWidget {
  final String command;
  const _CommandLine({required this.command});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              command,
              style: AppTextStyles.bodySmall.copyWith(
                fontFamily: 'monospace',
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_rounded, size: 16),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: command));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
          ),
        ],
      ),
    );
  }
}
