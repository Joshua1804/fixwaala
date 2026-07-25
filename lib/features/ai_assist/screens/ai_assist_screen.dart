import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../models/fault_classification.dart';
import '../services/ai_classifier_service.dart';

class AiAssistScreen extends StatefulWidget {
  const AiAssistScreen({super.key});

  @override
  State<AiAssistScreen> createState() => _AiAssistScreenState();
}

class _AiAssistScreenState extends State<AiAssistScreen> {
  FaultClassification? _result;
  ServiceCategory? _override;
  bool _running = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _run();
  }

  Future<void> _run() async {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        const {};
    final result = await AiClassifierService.instance.classifyWithAi(
      description: args['description'] ?? '',
      imageUrls: (args['images'] as List?)?.cast<String>() ?? const [],
    );
    if (!mounted) return;
    setState(() {
      _result = result;
      _running = false;
    });
  }

  void _confirm() {
    final category = _override ?? _result?.category ?? ServiceCategory.unknown;
    Navigator.of(context).pushNamed(
      RouteNames.ticketReview,
      arguments: {
        'category': category.name,
        'complexity': _result?.complexity.name,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI ticket assist')),
      body: _running
          ? const LoadingWidget(label: 'Analysing your problem...')
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_result?.safetyFlagged ?? false)
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
                            selected: (_override ?? _result?.category) == c,
                            onSelected: (_) => setState(() => _override = c),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Confidence: ${((_result?.confidence ?? 0) * 100).toStringAsFixed(0)}%',
                  ),
                  const Spacer(),
                  PrimaryButton(label: 'Confirm', onPressed: _confirm),
                ],
              ),
            ),
    );
  }
}
