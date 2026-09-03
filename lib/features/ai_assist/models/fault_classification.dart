import '../../../core/models/enums.dart';
import 'clarifying_question.dart';

class FaultClassification {
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final double confidence; // 0..1
  final bool safetyFlagged;
  final List<ClarifyingQuestion> clarifyingQuestions;

  const FaultClassification({
    required this.category,
    required this.complexity,
    required this.confidence,
    required this.safetyFlagged,
    required this.clarifyingQuestions,
  });
}
