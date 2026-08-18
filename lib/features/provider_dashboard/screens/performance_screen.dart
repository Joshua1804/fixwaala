import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/services/auth_service.dart';
import '../../service_lifecycle/models/job_model.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/analytics_model.dart';
import '../services/analytics_service.dart';

/// Performance Analytics Screen — weekly job trend, popular service
/// categories, and peak demand hours, rendered with `fl_chart`.
class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: FutureBuilder(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnap) {
          final providerId = userSnap.data?.id ?? AppConstants.demoProviderId;
          return StreamBuilder<Job>(
            stream: JobService.instance.watchAllChanges(),
            builder: (context, _) => FutureBuilder<ProviderAnalytics>(
              future: AnalyticsService.instance.load(providerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const LoadingWidget(
                    label: 'Crunching your numbers...',
                  );
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
                      child: _WeeklyTrendChart(
                        weeklyJobs: a.weeklyJobs,
                        dayLabels: _last7DayLabels(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Popular service categories',
                      child: _CategoryDistributionChart(
                        categoryDistribution: a.categoryDistribution,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _ChartCard(
                      title: 'Peak demand hours',
                      child: _PeakHoursChart(
                        peakDemandHours: a.peakDemandHours,
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
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

/// Last 7 days of completed-job counts as a line chart.
class _WeeklyTrendChart extends StatelessWidget {
  final List<int> weeklyJobs; // 7 entries, oldest first
  final List<String> dayLabels; // 7 entries, same order as weeklyJobs
  const _WeeklyTrendChart({required this.weeklyJobs, required this.dayLabels});

  @override
  Widget build(BuildContext context) {
    final maxY = (weeklyJobs.isEmpty
            ? 1
            : weeklyJobs.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);
    return SizedBox(
      height: 180,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY + 1,
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= dayLabels.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(dayLabels[i], style: AppTextStyles.caption);
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < weeklyJobs.length; i++)
                  FlSpot(i.toDouble(), weeklyJobs[i].toDouble()),
              ],
              isCurved: true,
              color: AppColors.primary,
              barWidth: 3,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Proportional split of completed jobs across service categories.
class _CategoryDistributionChart extends StatelessWidget {
  final Map<String, int> categoryDistribution;
  const _CategoryDistributionChart({required this.categoryDistribution});

  static const _palette = [
    AppColors.primary,
    AppColors.accent,
    AppColors.info,
    AppColors.warning,
    AppColors.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    if (categoryDistribution.isEmpty) {
      return const Text('No category data yet.');
    }
    final entries = categoryDistribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<int>(0, (sum, e) => sum + e.value);
    if (total == 0) return const Text('No category data yet.');

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: [
                for (var i = 0; i < entries.length; i++)
                  PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _palette[i % _palette.length],
                    title: '${(entries[i].value / total * 100).round()}%',
                    radius: 60,
                    titleStyle: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (var i = 0; i < entries.length; i++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _palette[i % _palette.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(entries[i].key, style: AppTextStyles.bodySmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Job count by hour of day (0-23).
class _PeakHoursChart extends StatelessWidget {
  final Map<int, int> peakDemandHours;
  const _PeakHoursChart({required this.peakDemandHours});

  @override
  Widget build(BuildContext context) {
    if (peakDemandHours.isEmpty) return const Text('No demand data yet.');
    final maxY = (peakDemandHours.values.isEmpty
            ? 1
            : peakDemandHours.values.reduce((a, b) => a > b ? a : b))
        .toDouble()
        .clamp(1, double.infinity);
    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          maxY: maxY + 1,
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 4,
                getTitlesWidget: (value, meta) =>
                    Text('${value.toInt()}h', style: AppTextStyles.caption),
              ),
            ),
          ),
          barGroups: [
            for (var hour = 0; hour < 24; hour++)
              BarChartGroupData(
                x: hour,
                barRods: [
                  BarChartRodData(
                    toY: (peakDemandHours[hour] ?? 0).toDouble(),
                    color: AppColors.accent,
                    width: 6,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
