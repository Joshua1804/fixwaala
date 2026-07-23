class ProviderAnalytics {
  final int totalJobs;
  final int completedJobs;
  final int cancelledJobs;
  final double earningsThisMonth;
  final double earningsTotal;
  final double ratingAverage;
  final int ratingCount;
  final double acceptanceRate; // 0..1
  final double completionRate; // 0..1
  final double cancellationRate; // 0..1
  final int avgResponseSeconds;
  final int avgArrivalMinutes;
  final List<int> weeklyJobs; // last 7 days, oldest first
  final Map<String, int> categoryDistribution;
  final Map<int, int> peakDemandHours; // hour of day (0-23) -> job count

  const ProviderAnalytics({
    required this.totalJobs,
    required this.completedJobs,
    required this.cancelledJobs,
    required this.earningsThisMonth,
    required this.earningsTotal,
    required this.ratingAverage,
    required this.ratingCount,
    required this.acceptanceRate,
    required this.completionRate,
    required this.cancellationRate,
    required this.avgResponseSeconds,
    required this.avgArrivalMinutes,
    required this.weeklyJobs,
    required this.categoryDistribution,
    required this.peakDemandHours,
  });

  static const empty = ProviderAnalytics(
    totalJobs: 0,
    completedJobs: 0,
    cancelledJobs: 0,
    earningsThisMonth: 0,
    earningsTotal: 0,
    ratingAverage: 0,
    ratingCount: 0,
    acceptanceRate: 0,
    completionRate: 0,
    cancellationRate: 0,
    avgResponseSeconds: 0,
    avgArrivalMinutes: 0,
    weeklyJobs: [0, 0, 0, 0, 0, 0, 0],
    categoryDistribution: {},
    peakDemandHours: {},
  );

  bool get hasHistory => totalJobs > 0;
}
