import '../../../core/models/enums.dart';

/// Final structured assessment produced after the customer answers the
/// AI-generated clarifying questions.
class ProblemSummary {
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final double confidence; // 0..1
  final bool safetyFlagged;
  final String summary;
  final List<String> recommendedEquipment;

  const ProblemSummary({
    required this.category,
    required this.complexity,
    required this.confidence,
    required this.safetyFlagged,
    required this.summary,
    required this.recommendedEquipment,
  });
}
