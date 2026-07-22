import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

class ProviderDashboardScreen extends StatelessWidget {
  const ProviderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: FutureBuilder<ProviderAnalytics>(
        future: AnalyticsService.instance.load('current-provider-id'),
        builder: (context, snapshot) {
          final a = snapshot.data ?? ProviderAnalytics.empty;
          return ListView(
            padding: const EdgeInsets.all(16),
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
                      label: 'Earnings',
                      value: '₹${a.earningsThisMonth.toStringAsFixed(0)}'),
                  _StatCard(
                      label: 'Rating',
                      value: a.ratingAverage.toStringAsFixed(1)),
                  _StatCard(
                      label: 'Completion',
                      value: '${(a.completionRate * 100).toStringAsFixed(0)}%'),
                  _StatCard(
                      label: 'Cancellations',
                      value:
                          '${(a.cancellationRate * 100).toStringAsFixed(0)}%'),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: const Text('Performance details'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context)
                    .pushNamed(RouteNames.providerPerformance),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}
