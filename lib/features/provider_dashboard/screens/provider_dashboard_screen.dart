import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

/// Provider Dashboard — overview hub with quick stats and navigation into
/// Earnings, Performance, and Trust Score detail screens.
class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnap) {
          final providerId = userSnap.data?.id ?? AppConstants.demoProviderId;
          return StreamBuilder<Job>(
            stream: JobService.instance.watchAllChanges(),
            builder: (context, _) {
              return FutureBuilder<ProviderAnalytics>(
                future: AnalyticsService.instance.load(providerId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingWidget(label: 'Loading your stats...');
                  }
                  final a = snapshot.data ?? ProviderAnalytics.empty;
                  if (!a.hasHistory) {
                    return _EmptyDashboard();
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        children: [
                          _StatCard(
                            label: 'This month',
                            value: '₹${a.earningsThisMonth.toStringAsFixed(0)}',
                            icon: Icons.payments_rounded,
                            color: AppColors.success,
                          ),
                          _StatCard(
                            label: 'Rating',
                            value: a.ratingCount == 0
                                ? '—'
                                : a.ratingAverage.toStringAsFixed(1),
                            icon: Icons.star_rounded,
                            color: AppColors.accent,
                          ),
                          _StatCard(
                            label: 'Completion rate',
                            value:
                                '${(a.completionRate * 100).toStringAsFixed(0)}%',
                            icon: Icons.check_circle_rounded,
                            color: AppColors.info,
                          ),
                          _StatCard(
                            label: 'Cancellations',
                            value:
                                '${(a.cancellationRate * 100).toStringAsFixed(0)}%',
                            icon: Icons.cancel_rounded,
                            color: AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _NavTile(
                        icon: Icons.account_balance_wallet_rounded,
                        title: 'Earnings summary',
                        subtitle:
                            'Total: ₹${a.earningsTotal.toStringAsFixed(0)}',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.providerEarnings),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        icon: Icons.bar_chart_rounded,
                        title: 'Performance analytics',
                        subtitle: 'Trends, categories & demand',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.providerPerformance),
                      ),
                      const SizedBox(height: 10),
                      _NavTile(
                        icon: Icons.verified_rounded,
                        title: 'Trust score',
                        subtitle: 'How customers see your reliability',
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed(RouteNames.providerTrustScore),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 64,
              color: AppColors.textHint.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No job history yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete your first job to see earnings, ratings, and performance here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.headlineSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
