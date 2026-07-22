import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../models/admin_model.dart';
import '../services/admin_service.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin dashboard')),
      body: FutureBuilder<AdminDashboardSummary>(
        future: AdminService.instance.dashboardSummary(),
        builder: (context, snapshot) {
          final s = snapshot.data ?? AdminDashboardSummary.empty;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Tile(
                title: 'Pending provider verifications',
                count: s.pendingVerifications,
                icon: Icons.verified_user,
                onTap: () => Navigator.of(context)
                    .pushNamed(RouteNames.adminVerificationReview),
              ),
              _Tile(
                title: 'Active tickets',
                count: s.activeTickets,
                icon: Icons.assignment,
                onTap: () {},
              ),
              _Tile(
                title: 'Matching failures',
                count: s.matchingFailures,
                icon: Icons.error_outline,
                onTap: () {},
              ),
              _Tile(
                title: 'Open reports',
                count: s.openReports,
                icon: Icons.report,
                onTap: () =>
                    Navigator.of(context).pushNamed(RouteNames.adminReports),
              ),
              _Tile(
                title: 'Safety alerts',
                count: s.safetyAlerts,
                icon: Icons.warning,
                color: Colors.red,
                onTap: () {},
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
  final int count;
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
        trailing: Text('$count',
            style: Theme.of(context).textTheme.headlineSmall),
        onTap: onTap,
      ),
    );
  }
}
