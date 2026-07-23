import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/admin_model.dart';
import '../services/admin_service.dart';

/// Admin Dashboard — active tickets, completed jobs, matching failures,
/// open reports, high-severity safety alerts, and suspended accounts.
///
/// Deliberately does not surface Aadhaar/selfie identity verification.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: FutureBuilder<AdminDashboardSummary>(
        future: AdminService.instance.dashboardSummary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LoadingWidget(label: 'Loading dashboard...');
          }
          final s = snapshot.data ?? AdminDashboardSummary.empty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Tile(
                title: 'Active tickets',
                count: s.activeTickets,
                icon: Icons.assignment_rounded,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.adminActiveTickets),
              ),
              _Tile(
                title: 'Completed jobs',
                count: s.completedJobs,
                icon: Icons.check_circle_rounded,
                color: AppColors.success,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.adminActiveTickets),
              ),
              _Tile(
                title: 'Matching failures',
                count: s.matchingFailures,
                icon: Icons.error_outline_rounded,
                onTap: () {},
              ),
              _Tile(
                title: 'Open reports',
                count: s.openReports,
                icon: Icons.report_rounded,
                color: AppColors.warning,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.adminReports),
              ),
              _Tile(
                title: 'High-severity safety alerts',
                count: s.highSeverityAlerts,
                icon: Icons.warning_rounded,
                color: AppColors.error,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.adminSafetyAlerts),
              ),
              _Tile(
                title: 'Suspended accounts',
                count: s.suspendedAccounts,
                icon: Icons.block_rounded,
                color: AppColors.textSecondary,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.adminAccounts),
              ),
              const Divider(height: 32),
              _Tile(
                title: 'Audit events',
                count: null,
                icon: Icons.history_rounded,
                onTap: () => Navigator.of(
                  context,
                ).pushNamed(RouteNames.adminAuditEvents),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String title;
  final int? count;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;

  const _Tile({
    required this.title,
    required this.count,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        trailing: count == null
            ? const Icon(Icons.chevron_right_rounded)
            : Text('$count', style: Theme.of(context).textTheme.headlineSmall),
        onTap: onTap,
      ),
    );
  }
}
