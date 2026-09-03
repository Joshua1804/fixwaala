import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/async_state_builder.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/utils/error_messages.dart';
import '../models/clarifying_qa.dart';
import '../models/clarifying_question.dart';
import '../models/fault_classification.dart';
import '../models/problem_summary.dart';
import '../services/ai_classifier_service.dart';

enum _Step { loadingInitial, questions, loadingFinal, result, failed }

class AiAssistScreen extends StatefulWidget {
  const AiAssistScreen({super.key});

  @override
  State<AiAssistScreen> createState() => _AiAssistScreenState();
}

class _AiAssistScreenState extends State<AiAssistScreen> {
  _Step _step = _Step.loadingInitial;
  FaultClassification? _initial;
  ProblemSummary? _final;
  ServiceCategory? _override;
  int _questionIndex = 0;
  final List<TextEditingController> _answerControllers = [];
  final Map<int, int?> _selectedRadioIndices = {};

  String _description = '';
  List<String> _images = const [];

  bool _ranOnce = false;
  String? _error;

  /// True when the AI produced nothing usable and the keyword rule engine
  /// stood in. Surfaced to the customer instead of silently handing them
  /// generic questions and a low-confidence category.
  bool _usedFallback = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ranOnce) return;
    _ranOnce = true;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        const {};
    _description = args['description'] as String? ?? '';
    _images = (args['images'] as List?)?.cast<String>() ?? const [];
    // Pre-selected on the home grid — respected unless the customer changes it.
    _override = args['seedCategory'] as ServiceCategory?;
    _run();
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// Runs the first AI pass.
  ///
  /// This had no `try`/`catch`: any unexpected throw left `_step` at
  /// [_Step.loadingInitial], so the customer sat on a spinner forever with no
  /// message and no way out. Every path now lands on a real state.
  Future<void> _run() async {
    setState(() {
      _step = _Step.loadingInitial;
      _error = null;
    });
    try {
      final classified = await AiClassifierService.instance.classifyWithAi(
        description: _description,
        imageUrls: _images,
      );
      if (!mounted) return;
      setState(() {
        _initial = classified.result;
        _usedFallback = !classified.usedAi;
        _answerControllers
          ..clear()
          ..addAll(
            List.generate(
              classified.result.clarifyingQuestions.length,
              (_) => TextEditingController(),
            ),
          );
        _questionIndex = 0;
        _step = classified.result.clarifyingQuestions.isEmpty
            ? _Step.loadingFinal
            : _Step.questions;
      });
      if (_step == _Step.loadingFinal) {
        await _runFinal();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(error);
        _step = _Step.failed;
      });
    }
  }

  Future<void> _runFinal() async {
    try {
      final qaPairs = List.generate(
        _initial?.clarifyingQuestions.length ?? 0,
        (i) => ClarifyingQa(
          question: _initial!.clarifyingQuestions[i].question,
          answer: _answerControllers[i].text.trim(),
        ),
      );
      final summarized = await AiClassifierService.instance.summarizeWithAi(
        description: _description,
        qaPairs: qaPairs,
        fallbackCategory: _initial?.category ?? ServiceCategory.unknown,
        fallbackComplexity: _initial?.complexity ?? ProblemComplexity.medium,
      );
      if (!mounted) return;
      setState(() {
        _final = summarized.result;
        // Either step falling back to the rule engine is worth surfacing —
        // a customer who got real AI questions but a rule-based summary
        // still deserves to know the final read is the lower-confidence one.
        _usedFallback = _usedFallback || !summarized.usedAi;
        _step = _Step.result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ErrorMessages.friendly(error);
        _step = _Step.failed;
      });
    }
  }

  /// Abandons AI assist and continues to the review step with what the
  /// customer already typed. AI triage is a convenience — it must never be
  /// the thing that stops someone reporting a burst pipe.
  void _skipAi() {
    setState(() {
      _final = null;
      _step = _Step.result;
    });
  }

  void _nextQuestion() {
    final isLast = _questionIndex == _answerControllers.length - 1;
    if (isLast) {
      setState(() => _step = _Step.loadingFinal);
      _runFinal();
    } else {
      setState(() => _questionIndex++);
    }
  }

  void _previousQuestion() {
    if (_questionIndex == 0) return;
    setState(() => _questionIndex--);
  }

  List<ClarifyingQa> get _qaPairs => List.generate(
    _initial?.clarifyingQuestions.length ?? 0,
    (i) => ClarifyingQa(
      question: _initial!.clarifyingQuestions[i].question,
      answer: _answerControllers[i].text.trim(),
    ),
  );

  void _confirm() {
    final category = _override ?? _final?.category ?? ServiceCategory.unknown;
    Navigator.of(context).pushNamed(
      RouteNames.ticketReview,
      arguments: {
        'description': _description,
        'images': _images,
        'category': category.name,
        'complexity': _final?.complexity.name,
        'aiSummary': _final?.summary,
        'recommendedEquipment': _final?.recommendedEquipment ?? const [],
        'clarifyingQa': _qaPairs.map((qa) => qa.toMap()).toList(),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI ticket assist')),
      body: switch (_step) {
        _Step.loadingInitial => const LoadingWidget(
          label: 'Analysing your problem...',
        ),
        _Step.questions => _buildQuestionStep(),
        _Step.loadingFinal => const LoadingWidget(
          label: 'Putting together your summary...',
        ),
        _Step.result => _buildResultStep(),
        _Step.failed => _buildFailedStep(),
      },
    );
  }

  Widget _buildFailedStep() => Padding(
    padding: const EdgeInsets.all(24),
    child: AsyncErrorView(
      message:
          '${_error ?? 'AI assist is unavailable right now.'}\n\n'
          'You can try again, or continue and pick the category yourself.',
      onRetry: _run,
    ),
  );

  Widget _buildQuestionStep() {
    final questions = _initial!.clarifyingQuestions;
    final total = questions.length;
    final isLast = _questionIndex == total - 1;
    final currentQuestion = questions[_questionIndex];
    final options = currentQuestion.options;
    final selectedOptionIndex = _selectedRadioIndices[_questionIndex];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usedFallback) ...[
            const _AiUnavailableBanner(),
            const SizedBox(height: 12),
          ],
          LinearProgressIndicator(value: (_questionIndex + 1) / total),
          const SizedBox(height: 12),
          Text(
            'Question ${_questionIndex + 1}/$total',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          Text(
            currentQuestion.question,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (options.isNotEmpty) ...[
                    Text(
                      'Suggested answers',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(options.length, (optIdx) {
                      final optionText = options[optIdx];
                      final isSelected = selectedOptionIndex == optIdx;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedRadioIndices[_questionIndex] = optIdx;
                              _answerControllers[_questionIndex].text =
                                  optionText;
                              _answerControllers[_questionIndex].selection =
                                  TextSelection.fromPosition(
                                TextPosition(offset: optionText.length),
                              );
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary.withValues(alpha: 0.1)
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.divider,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: optIdx,
                                  groupValue: selectedOptionIndex,
                                  activeColor: AppColors.primary,
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _selectedRadioIndices[_questionIndex] =
                                            val;
                                        _answerControllers[_questionIndex]
                                            .text = optionText;
                                        _answerControllers[_questionIndex]
                                                .selection =
                                            TextSelection.fromPosition(
                                          TextPosition(
                                              offset: optionText.length),
                                        );
                                      });
                                    }
                                  },
                                ),
                                Expanded(
                                  child: Text(
                                    optionText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.normal,
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Or type your own answer',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: ValueKey(_questionIndex),
                    controller: _answerControllers[_questionIndex],
                    maxLines: 3,
                    autofocus: options.isEmpty,
                    onChanged: (text) {
                      if (selectedOptionIndex != null) {
                        if (text != options[selectedOptionIndex]) {
                          setState(() {
                            _selectedRadioIndices[_questionIndex] = null;
                          });
                        }
                      }
                    },
                    decoration: const InputDecoration(
                      hintText: 'Type custom answer here...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (_questionIndex > 0)
                Expanded(
                  child: PrimaryButton(
                    label: 'Back',
                    outlined: true,
                    onPressed: _previousQuestion,
                  ),
                ),
              if (_questionIndex > 0) const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: isLast ? 'Finish' : 'Next',
                  onPressed: _nextQuestion,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: _nextQuestion,
            child: Text(isLast ? 'Not sure — finish' : 'Not sure — skip'),
          ),
          TextButton(onPressed: _skipAi, child: const Text('Skip AI assist')),
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_usedFallback) ...[
            const _AiUnavailableBanner(),
            const SizedBox(height: 12),
          ],
          if (_final?.safetyFlagged ?? false)
            Card(
              color: AppColors.error.withValues(alpha: 0.08),
              child: const ListTile(
                leading: Icon(Icons.warning, color: AppColors.error),
                title: Text('Potential safety concern detected'),
                subtitle: Text(
                  'Please move to a safe distance. Consider emergency services if urgent.',
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Suggested category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ServiceCategory.values
                .where((c) => c != ServiceCategory.unknown)
                .map(
                  (c) => ChoiceChip(
                    label: Text(c.name),
                    selected: (_override ?? _final?.category) == c,
                    onSelected: (_) => setState(() => _override = c),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          Text(
            'Confidence: ${((_final?.confidence ?? 0) * 100).toStringAsFixed(0)}%',
          ),
          if ((_final?.summary ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Summary', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(_final!.summary),
          ],
          if ((_final?.recommendedEquipment ?? const []).isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recommended tools/parts',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _final!.recommendedEquipment
                  .map((e) => Chip(label: Text(e)))
                  .toList(),
            ),
          ],
          const SizedBox(height: 32),
          PrimaryButton(label: 'Confirm', onPressed: _confirm),
        ],
      ),
    );
  }
}

/// Tells the customer the AI could not be reached, without blocking them.
class _AiUnavailableBanner extends StatelessWidget {
  const _AiUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'AI assist is unavailable — these are standard questions. '
              'You can answer what you know and continue.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
