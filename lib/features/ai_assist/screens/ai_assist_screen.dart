import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/clarifying_qa.dart';
import '../models/fault_classification.dart';
import '../models/problem_summary.dart';
import '../services/ai_classifier_service.dart';

enum _Step { loadingInitial, questions, loadingFinal, result }

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

  String _description = '';
  List<String> _images = const [];

  bool _ranOnce = false;

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
    _run();
  }

  @override
  void dispose() {
    for (final c in _answerControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run() async {
    final result = await AiClassifierService.instance.classifyWithAi(
      description: _description,
      imageUrls: _images,
    );
    if (!mounted) return;
    setState(() {
      _initial = result;
      _answerControllers
        ..clear()
        ..addAll(
          List.generate(
            result.clarifyingQuestions.length,
            (_) => TextEditingController(),
          ),
        );
      _questionIndex = 0;
      _step = result.clarifyingQuestions.isEmpty
          ? _Step.loadingFinal
          : _Step.questions;
    });
    if (_step == _Step.loadingFinal) {
      _runFinal();
    }
  }

  Future<void> _runFinal() async {
    final qaPairs = List.generate(
      _initial?.clarifyingQuestions.length ?? 0,
      (i) => ClarifyingQa(
        question: _initial!.clarifyingQuestions[i],
        answer: _answerControllers[i].text.trim(),
      ),
    );
    final result = await AiClassifierService.instance.summarizeWithAi(
      description: _description,
      qaPairs: qaPairs,
      fallbackCategory: _initial?.category ?? ServiceCategory.unknown,
      fallbackComplexity: _initial?.complexity ?? ProblemComplexity.medium,
    );
    if (!mounted) return;
    setState(() {
      _final = result;
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
      question: _initial!.clarifyingQuestions[i],
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
      },
    );
  }

  Widget _buildQuestionStep() {
    final questions = _initial!.clarifyingQuestions;
    final total = questions.length;
    final isLast = _questionIndex == total - 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: (_questionIndex + 1) / total),
          const SizedBox(height: 12),
          Text(
            'Question ${_questionIndex + 1}/$total',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 16),
          Text(
            questions[_questionIndex],
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            key: ValueKey(_questionIndex),
            controller: _answerControllers[_questionIndex],
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Your answer',
              border: OutlineInputBorder(),
            ),
          ),
          const Spacer(),
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
        ],
      ),
    );
  }

  Widget _buildResultStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const Spacer(),
          PrimaryButton(label: 'Confirm', onPressed: _confirm),
        ],
      ),
    );
  }
}
