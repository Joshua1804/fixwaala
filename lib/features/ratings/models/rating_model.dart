import 'package:cloud_firestore/cloud_firestore.dart' as fs;

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

  Map<String, dynamic> toMap() => {
    'id': id,
    'jobId': jobId,
    'fromUserId': fromUserId,
    'toUserId': toUserId,
    'direction': direction.name,
    'stars': stars,
    if (review != null) 'review': review,
    'createdAt': fs.Timestamp.fromDate(createdAt),
  };

  factory Rating.fromMap(Map<String, dynamic> map) => Rating(
    id: map['id'] as String,
    jobId: map['jobId'] as String,
    fromUserId: map['fromUserId'] as String,
    toUserId: map['toUserId'] as String,
    direction: RatingDirection.values.byName(map['direction'] as String),
    stars: (map['stars'] as num).toInt(),
    review: map['review'] as String?,
    createdAt: map['createdAt'] is fs.Timestamp
        ? (map['createdAt'] as fs.Timestamp).toDate()
        : DateTime.tryParse(map['createdAt']?.toString() ?? '') ??
              DateTime.now(),
  );
}
