import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../core/admin_route_names.dart';
import '../../widgets/admin_page_scaffold.dart';
import '../../widgets/admin_state_views.dart';
import '../../widgets/admin_stat_card.dart';
import 'services/admin_dashboard_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late Future<DashboardStats> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = AdminDashboardService.instance.load();
  }

  void _retry() => setState(_load);

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      title: 'Dashboard',
      subtitle: 'Platform overview, updated on load.',
      actions: [
        OutlinedButton.icon(
          onPressed: () => setState(_load),
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      child: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AdminLoadingView(label: 'Loading platform stats…');
          }
          if (snapshot.hasError) {
            return AdminErrorView(error: snapshot.error!, onRetry: _retry);
          }
          final stats = snapshot.data!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!AppConstants.scheduledFunctionsDeployed)
                _BackendStatusBanner(),
              if (!AppConstants.scheduledFunctionsDeployed)
                const SizedBox(height: AppSpacing.xxl),
              Text('People', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _StatGrid(
                cards: [
                  AdminStatCard(
                    icon: Icons.person_outline_rounded,
                    value: '${stats.totalCustomers}',
                    label: 'Customers',
                    color: AppColors.info,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AdminRouteNames.users),
                  ),
                  AdminStatCard(
                    icon: Icons.engineering_outlined,
                    value: '${stats.totalProviders}',
                    label: 'Providers',
                    color: AppColors.primary,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AdminRouteNames.users),
                  ),
                  AdminStatCard(
                    icon: Icons.phone_iphone_rounded,
                    value: '${stats.registeredDevices}',
                    label: 'Registered devices',
                    color: AppColors.secondary,
                    subtext: 'Push reach (informational)',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Marketplace activity', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _StatGrid(
                cards: [
                  AdminStatCard(
                    icon: Icons.confirmation_number_outlined,
                    value: '${stats.activeTickets}',
                    label: 'Active tickets',
                    color: AppColors.info,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.tickets),
                  ),
                  AdminStatCard(
                    icon: Icons.error_outline_rounded,
                    value: '${stats.failedTickets}',
                    label: 'Failed to match',
                    color: AppColors.warning,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.tickets),
                  ),
                  AdminStatCard(
                    icon: Icons.work_outline_rounded,
                    value: '${stats.activeJobs}',
                    label: 'Active jobs',
                    color: AppColors.primary,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AdminRouteNames.jobs),
                  ),
                  AdminStatCard(
                    icon: Icons.task_alt_rounded,
                    value: '${stats.completedJobs}',
                    label: 'Completed jobs',
                    color: AppColors.success,
                    onTap: () =>
                        Navigator.of(context).pushNamed(AdminRouteNames.jobs),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Payments', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _StatGrid(
                cards: [
                  AdminStatCard(
                    icon: Icons.payments_outlined,
                    value: '₹${stats.totalRevenue.toStringAsFixed(0)}',
                    label: 'Total processed (simulated)',
                    color: AppColors.success,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.payments),
                  ),
                  AdminStatCard(
                    icon: Icons.receipt_long_outlined,
                    value: '${stats.successfulPayments}',
                    label: 'Successful payments',
                    color: AppColors.info,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.payments),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Trust & safety', style: AppTextStyles.titleMedium),
              const SizedBox(height: AppSpacing.md),
              _StatGrid(
                cards: [
                  AdminStatCard(
                    icon: Icons.flag_outlined,
                    value: '${stats.openReports}',
                    label: 'Open reports',
                    color: stats.openReports > 0
                        ? AppColors.warning
                        : AppColors.success,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.reports),
                  ),
                  AdminStatCard(
                    icon: Icons.emergency_outlined,
                    value: '${stats.unresolvedSafetyAlerts}',
                    label: 'Unresolved safety alerts',
                    color: stats.unresolvedSafetyAlerts > 0
                        ? AppColors.error
                        : AppColors.success,
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AdminRouteNames.safetyAlerts),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final List<Widget> cards;
  const _StatGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(1, 5);
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: AppSpacing.lg,
          mainAxisSpacing: AppSpacing.lg,
          childAspectRatio: 1.5,
          children: cards,
        );
      },
    );
  }
}

class _BackendStatusBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: AppColors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cloud Functions are not deployed',
                  style: AppTextStyles.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  'Push notifications, automatic radius expansion, and '
                  'candidate-lease expiry are running client-side fallbacks '
                  'instead — see Monitoring for details. Requires the Blaze '
                  'plan to fix.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushNamed(AdminRouteNames.monitoring),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}
