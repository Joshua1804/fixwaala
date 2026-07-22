import '../models/analytics_model.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  Future<ProviderAnalytics> load(String providerId) async {
    // TODO: aggregate from Firestore (jobs, payments, ratings).
    return ProviderAnalytics.empty;
  }
}
