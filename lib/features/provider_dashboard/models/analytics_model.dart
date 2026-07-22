class ProviderAnalytics {
  final double earningsThisMonth;
  final double ratingAverage;
  final double completionRate; // 0..1
  final double cancellationRate; // 0..1
  final int avgResponseSeconds;
  final int avgArrivalMinutes;
  final List<int> weeklyJobs; // last 7 days
  final Map<String, int> categoryDistribution;

  const ProviderAnalytics({
    required this.earningsThisMonth,
    required this.ratingAverage,
    required this.completionRate,
    required this.cancellationRate,
    required this.avgResponseSeconds,
    required this.avgArrivalMinutes,
    required this.weeklyJobs,
    required this.categoryDistribution,
  });

  static const empty = ProviderAnalytics(
    earningsThisMonth: 0,
    ratingAverage: 0,
    completionRate: 0,
    cancellationRate: 0,
    avgResponseSeconds: 0,
    avgArrivalMinutes: 0,
    weeklyJobs: [0, 0, 0, 0, 0, 0, 0],
    categoryDistribution: {},
  );
}
