import '../models/rating_model.dart';

class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  Future<void> submit(Rating rating) async {
    // TODO:
    //   • reject if duplicate rating for (jobId, fromUserId) exists
    //   • write rating doc
    //   • recompute rolling averages + reliability score on the target user
  }

  Future<double> averageForUser(String userId) async => 0;

  Future<int> completedJobs(String userId) async => 0;
}
