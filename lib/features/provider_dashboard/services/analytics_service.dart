import '../../../core/models/enums.dart';
import '../../payment/services/payment_service.dart';
import '../../ratings/services/rating_service.dart';
import '../../service_lifecycle/services/job_service.dart';
import '../models/analytics_model.dart';
import 'trust_score_calculator.dart';

/// Aggregates a provider's job, payment, and rating history into the
/// summary numbers shown on the Provider Dashboard, Earnings, and
/// Performance Analytics screens.
///
/// Computed on the fly from [JobService] / [RatingService] /
/// [PaymentService] rather than maintaining separate running counters —
/// there is a single source of truth (the job history) and no risk of the
/// aggregates drifting out of sync with it.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<ProviderAnalytics> load(String providerId) async {
    final jobs = JobService.instance.allJobsForProvider(providerId);
    if (jobs.isEmpty) return ProviderAnalytics.empty;

    final completed = jobs
        .where((j) => j.status == JobStatus.completed)
        .toList();
    final cancelled = jobs
        .where((j) => j.status == JobStatus.cancelled)
        .toList();
    final accepted = jobs.where((j) => j.acceptedAt != null).toList();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    double earningsThisMonth = 0;
    double earningsTotal = 0;
    for (final job in jobs) {
      final payment = PaymentService.instance.paymentForJob(job.jobId);
      if (payment == null || payment.status != PaymentStatus.success) continue;
      earningsTotal += payment.amount;
      if (!payment.processedAt.isBefore(monthStart)) {
        earningsThisMonth += payment.amount;
      }
    }

    final responseTimes = jobs
        .map((j) => j.responseTime)
        .whereType<Duration>()
        .map((d) => d.inSeconds)
        .toList();
    final avgResponseSeconds = responseTimes.isEmpty
        ? 0
        : (responseTimes.reduce((a, b) => a + b) / responseTimes.length)
              .round();

    final arrivalTimes = jobs
        .map((j) => j.arrivalTime)
        .whereType<Duration>()
        .map((d) => d.inSeconds / 60.0)
        .toList();
    final avgArrivalMinutes = arrivalTimes.isEmpty
        ? 0
        : (arrivalTimes.reduce((a, b) => a + b) / arrivalTimes.length).round();

    final weeklyJobs = List<int>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: 6 - i));
      weeklyJobs[i] = completed
          .where(
            (j) =>
                j.completedAt != null &&
                j.completedAt!.year == day.year &&
                j.completedAt!.month == day.month &&
                j.completedAt!.day == day.day,
          )
          .length;
    }

    final categoryDistribution = <String, int>{};
    for (final job in jobs) {
      final key = _categoryLabel(job.category);
      categoryDistribution[key] = (categoryDistribution[key] ?? 0) + 1;
    }

    final peakDemandHours = <int, int>{};
    for (final job in jobs) {
      final hour = job.createdAt.hour;
      peakDemandHours[hour] = (peakDemandHours[hour] ?? 0) + 1;
    }

    return ProviderAnalytics(
      totalJobs: jobs.length,
      completedJobs: completed.length,
      cancelledJobs: cancelled.length,
      earningsThisMonth: earningsThisMonth,
      earningsTotal: earningsTotal,
      ratingAverage: RatingService.instance.averageForUser(providerId),
      ratingCount: RatingService.instance.ratingCountForUser(providerId),
      acceptanceRate: jobs.isEmpty ? 0 : accepted.length / jobs.length,
      completionRate: (completed.length + cancelled.length) == 0
          ? 0
          : completed.length / (completed.length + cancelled.length),
      cancellationRate: jobs.isEmpty ? 0 : cancelled.length / jobs.length,
      avgResponseSeconds: avgResponseSeconds,
      avgArrivalMinutes: avgArrivalMinutes,
      weeklyJobs: weeklyJobs,
      categoryDistribution: categoryDistribution,
      peakDemandHours: peakDemandHours,
    );
  }

  Future<TrustScoreResult> trustScore(String providerId) async {
    final a = await load(providerId);
    return TrustScoreCalculator.calculate(
      completedJobs: a.completedJobs,
      ratingAverage: a.ratingAverage,
      completionRate: a.completionRate,
      cancellationRate: a.cancellationRate,
      avgResponseSeconds: a.avgResponseSeconds,
    );
  }

  String _categoryLabel(ServiceCategory c) => switch (c) {
    ServiceCategory.plumber => 'Plumbing',
    ServiceCategory.electrician => 'Electrical',
    ServiceCategory.carpenter => 'Carpentry',
    ServiceCategory.unknown => 'Other',
  };
}
