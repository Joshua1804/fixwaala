import '../../../core/models/enums.dart';

class Rating {
  final String id;
  final String jobId;
  final String fromUserId;
  final String toUserId;
  final RatingDirection direction;
  final int stars; // 1..5
  final String? review;
  final DateTime createdAt;

  const Rating({
    required this.id,
    required this.jobId,
    required this.fromUserId,
    required this.toUserId,
    required this.direction,
    required this.stars,
    required this.createdAt,
    this.review,
  });
}
