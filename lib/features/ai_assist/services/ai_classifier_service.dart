import '../../../core/models/enums.dart';
import '../models/fault_classification.dart';

/// Combines a keyword rule engine with an LLM call for fault classification.
class AiClassifierService {
  AiClassifierService._();
  static final AiClassifierService instance = AiClassifierService._();

  static const _plumbingHints = ['leak', 'pipe', 'tap', 'drain', 'sink', 'flush'];
  static const _electricalHints = ['fan', 'light', 'switch', 'wire', 'shock', 'socket'];
  static const _carpentryHints = ['door', 'window', 'wood', 'furniture', 'hinge', 'cupboard'];
  static const _unsafeHints = ['spark', 'smoke', 'burn', 'gas leak'];

  bool containsSafetyKeyword(String description) {
    final lower = description.toLowerCase();
    return _unsafeHints.any(lower.contains);
  }

  FaultClassification classifyByRules(String description) {
    final lower = description.toLowerCase();
    ServiceCategory category = ServiceCategory.unknown;
    if (_plumbingHints.any(lower.contains)) {
      category = ServiceCategory.plumber;
    } else if (_electricalHints.any(lower.contains)) {
      category = ServiceCategory.electrician;
    } else if (_carpentryHints.any(lower.contains)) {
      category = ServiceCategory.carpenter;
    }
    return FaultClassification(
      category: category,
      complexity: ProblemComplexity.medium,
      confidence: category == ServiceCategory.unknown ? 0.3 : 0.75,
      safetyFlagged: containsSafetyKeyword(description),
      clarifyingQuestions: const [],
    );
  }

  Future<FaultClassification> classifyWithAi({
    required String description,
    required List<String> imageUrls,
  }) async {
    // TODO: call remote AI endpoint (Vertex AI / OpenAI-style) for a
    // structured classification response. Fallback to rules on failure.
    return classifyByRules(description);
  }

  Future<List<String>> guidedQuestions(ServiceCategory category) async {
    return switch (category) {
      ServiceCategory.plumber => const [
          'Is water actively leaking now?',
          'Which fixture is affected?',
        ],
      ServiceCategory.electrician => const [
          'Does the circuit trip repeatedly?',
          'Any burning smell?',
        ],
      ServiceCategory.carpenter => const [
          'Is anything broken beyond alignment?',
          'Material — wood, MDF, or plywood?',
        ],
      _ => const ['Can you describe the problem in one line?'],
    };
  }
}
