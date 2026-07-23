import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

/// Performance Analytics Screen — weekly job trend, popular service
/// categories, and peak demand hours. Uses small hand-rolled bar charts so
/// no chart package dependency is required.
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  // NOTE: uses a shared demo provider id — see AppConstants.demoProviderId.
  String get _providerId => AppConstants.demoProviderId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: StreamBuilder<Job>(
        stream: JobService.instance.watchAllChanges(),
        builder: (context, _) => FutureBuilder<ProviderAnalytics>(
          future: AnalyticsService.instance.load(_providerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const LoadingWidget(label: 'Crunching your numbers...');
            }
            final a = snapshot.data ?? ProviderAnalytics.empty;
            if (!a.hasHistory) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        size: 64,
                        color: AppColors.textHint.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Not enough data yet',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Trends appear once you start completing jobs.',
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

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _ChartCard(
                  title: 'Key metrics',
                  child: _MetricsGrid(analytics: a),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Jobs completed — last 7 days',
                  child: _BarRow(
                    values: a.weeklyJobs.map((v) => v.toDouble()).toList(),
                    labels: _last7DayLabels(),
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Popular service categories',
                  child: _CategoryBars(distribution: a.categoryDistribution),
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Peak demand hours',
                  child: _PeakHoursBars(hours: a.peakDemandHours),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<String> _last7DayLabels() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return days[day.weekday - 1];
    });
  }
}

/// Surfaces the analytics fields that otherwise had nowhere to appear:
/// acceptance rate, average response/arrival time, and completed job count.
class _MetricsGrid extends StatelessWidget {
  final ProviderAnalytics analytics;
  const _MetricsGrid({required this.analytics});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.4,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        _MetricTile(
          label: 'Completed jobs',
          value: '${analytics.completedJobs}',
        ),
        _MetricTile(
          label: 'Acceptance rate',
          value: '${(analytics.acceptanceRate * 100).toStringAsFixed(0)}%',
        ),
        _MetricTile(
          label: 'Avg. response time',
          value: _formatSeconds(analytics.avgResponseSeconds),
        ),
        _MetricTile(
          label: 'Avg. arrival time',
          value: '${analytics.avgArrivalMinutes} min',
        ),
      ],
    );
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final minutes = seconds ~/ 60;
    final rem = seconds % 60;
    return rem == 0 ? '${minutes}m' : '${minutes}m ${rem}s';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// A simple equal-width vertical bar chart.
class _BarRow extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final Color color;

  const _BarRow({
    required this.values,
    required this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.fold<double>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${values[i].toInt()}', style: AppTextStyles.caption),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 70 * (values[i] / maxV).clamp(0.05, 1.0),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(labels[i], style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryBars extends StatelessWidget {
  final Map<String, int> distribution;
  const _CategoryBars({required this.distribution});

  @override
  Widget build(BuildContext context) {
    if (distribution.isEmpty) return const Text('No category data yet.');
    final total = distribution.values.fold<int>(0, (a, b) => a + b);
    final entries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      children: [
        for (final e in entries)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text(e.key, style: AppTextStyles.bodySmall),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : e.value / total,
                      minHeight: 10,
                      backgroundColor: AppColors.divider.withValues(alpha: 0.4),
                      valueColor: const AlwaysStoppedAnimation(
                        AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${e.value}', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
      ],
    );
  }
}

class _PeakHoursBars extends StatelessWidget {
  final Map<int, int> hours;
  const _PeakHoursBars({required this.hours});

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const Text('No demand data yet.');
    final maxV = hours.values.fold<int>(1, (m, v) => v > m ? v : m);
    final sortedHours = hours.keys.toList()..sort();
    return SizedBox(
      height: 100,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final h in sortedHours)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 18,
                      height: 60 * (hours[h]! / maxV).clamp(0.1, 1.0),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('$h:00', style: AppTextStyles.caption),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
