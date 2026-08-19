import '../../../core/models/enums.dart';
import '../models/clarifying_qa.dart';
import '../models/fault_classification.dart';
import '../models/problem_summary.dart';
import 'gemini_ai_service.dart';

/// Combines a keyword rule engine with an LLM call for fault classification.
class AiClassifierService {
  AiClassifierService._();
  static final AiClassifierService instance = AiClassifierService._();

  static const _plumbingHints = [
    'leak',
    'pipe',
    'tap',
    'drain',
    'sink',
    'flush',
  ];
  static const _electricalHints = [
    'fan',
    'light',
    'switch',
    'wire',
    'shock',
    'socket',
  ];
  static const _carpentryHints = [
    'door',
    'window',
    'wood',
    'furniture',
    'hinge',
    'cupboard',
  ];
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
      clarifyingQuestions: guidedQuestions(category),
    );
  }

  /// [usedAi] is false whenever [GeminiAiService] returned null for *any*
  /// reason — not configured, timed out, or a malformed response — and the
  /// rule-based classifier stood in instead. Checking
  /// `GeminiAiService.instance.isConfigured` after the fact used to be the
  /// only signal callers had, which only catches "no key compiled in" and
  /// stays silent about a configured call that failed at runtime.
  Future<({FaultClassification result, bool usedAi})> classifyWithAi({
    required String description,
    required List<String> imageUrls,
  }) async {
    final aiResult = await GeminiAiService.instance
        .classifyAndGenerateQuestions(
          description: description,
          imageUrls: imageUrls,
        );
    if (aiResult == null) {
      return (result: classifyByRules(description), usedAi: false);
    }
    return (
      result: FaultClassification(
        category: aiResult.category,
        complexity: aiResult.complexity,
        confidence: aiResult.confidence,
        safetyFlagged:
            aiResult.safetyFlag || containsSafetyKeyword(description),
        clarifyingQuestions: aiResult.questions,
      ),
      usedAi: true,
    );
  }

  /// Final structured summary after the customer has answered the
  /// clarifying questions. Falls back to a rule-based summary if Gemini
  /// is unavailable or fails; see [classifyWithAi] on why [usedAi] is
  /// reported explicitly rather than inferred from configuration state.
  Future<({ProblemSummary result, bool usedAi})> summarizeWithAi({
    required String description,
    required List<ClarifyingQa> qaPairs,
    required ServiceCategory fallbackCategory,
    required ProblemComplexity fallbackComplexity,
  }) async {
    final result = await GeminiAiService.instance.summarize(
      description: description,
      qaPairs: qaPairs,
    );
    if (result == null) {
      return (
        result: ProblemSummary(
          category: fallbackCategory,
          complexity: fallbackComplexity,
          confidence: fallbackCategory == ServiceCategory.unknown ? 0.3 : 0.5,
          safetyFlagged: containsSafetyKeyword(description),
          summary: description,
          recommendedEquipment: const [],
        ),
        usedAi: false,
      );
    }
    return (
      result: ProblemSummary(
        category: result.category,
        complexity: result.complexity,
        confidence: result.confidence,
        safetyFlagged:
            result.safetyFlag || containsSafetyKeyword(description),
        summary: result.summary,
        recommendedEquipment: result.recommendedEquipment,
      ),
      usedAi: true,
    );
  }

  List<String> guidedQuestions(ServiceCategory category) {
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
