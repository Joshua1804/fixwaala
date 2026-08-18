import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatting.dart';
import '../../../features/reports_safety/models/report_model.dart';
import '../../core/admin_auth_service.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_confirm_dialog.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_status_chip.dart';
import 'services/admin_moderation_service.dart';

/// SOS alerts, live. Unresolved-only by default — this is the one screen in
/// the admin module where waiting for a manual refresh is the wrong design:
/// see `sos_screen.dart` in the mobile app for what "not monitored 24/7"
/// this screen exists to partially address.
class AdminSafetyAlertsScreen extends StatefulWidget {
  const AdminSafetyAlertsScreen({super.key});

  @override
  State<AdminSafetyAlertsScreen> createState() =>
      _AdminSafetyAlertsScreenState();
}

class _AdminSafetyAlertsScreenState extends State<AdminSafetyAlertsScreen> {
  bool _showResolved = false;
  bool _busyId = false;

  Future<void> _resolve(SafetyAlert alert) async {
    final confirmed = await showAdminConfirmDialog(
      context,
      title: 'Mark resolved',
      message: 'Confirm this safety alert has been handled.',
      confirmLabel: 'Mark resolved',
    );
    if (!confirmed) return;
    setState(() => _busyId = true);
    try {
      await AdminModerationService.instance.resolveSafetyAlert(
        alert,
        adminId: AdminAuthService.instance.currentUid ?? 'unknown',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Safety alerts',
      subtitle: 'Live SOS alerts raised from active jobs.',
      actions: [
        FilterChip(
          label: const Text('Show resolved'),
          selected: _showResolved,
          onSelected: (v) => setState(() => _showResolved = v),
        ),
      ],
      child: StreamBuilder<List<SafetyAlert>>(
        stream: AdminModerationService.instance.watchSafetyAlerts(
          resolved: _showResolved ? null : false,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView();
          }
          if (snapshot.hasError) {
            return AdminErrorView(error: snapshot.error!);
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return AdminEmptyView(
              title: _showResolved
                  ? 'No safety alerts'
                  : 'No unresolved alerts',
              message: _showResolved
                  ? 'No safety alerts have ever been raised.'
                  : 'Every safety alert has been resolved.',
              icon: Icons.shield_outlined,
            );
          }
          return Column(
            children: alerts.map((alert) {
              return Container(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: alert.resolved
                      ? Theme.of(context).cardTheme.color
                      : AppColors.error.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: alert.resolved
                        ? AppColors.divider.withValues(alpha: 0.6)
                        : AppColors.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emergency_outlined,
                      color: alert.resolved
                          ? AppColors.textHint
                          : AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raised by user ${alert.userId}',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            RelativeTime.format(alert.raisedAt),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (alert.jobId != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).pushNamed(
                          AdminRouteNames.jobDetail,
                          arguments: alert.jobId,
                        ),
                        child: const Text('Open job'),
                      ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pushNamed(
                        AdminRouteNames.userDetail,
                        arguments: alert.userId,
                      ),
                      child: const Text('Open user'),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (alert.resolved)
                      AdminStatusChip.semantic('Resolved', tone: AdminTone.good)
                    else
                      FilledButton(
                        onPressed: _busyId ? null : () => _resolve(alert),
                        child: const Text('Resolve'),
                      ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
