import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/report_model.dart';
import '../services/report_service.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _descriptionController = TextEditingController();
  String _reason = 'Provider misbehaved';
  ReportSeverity _severity = ReportSeverity.medium;
  bool _submitting = false;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await ReportService.instance.submitReport(
      Report(
        id: 'report-${DateTime.now().microsecondsSinceEpoch}',
        reporterId: 'current-user-id',
        reason: _reason,
        description: _descriptionController.text,
        evidenceUrls: const [],
        severity: _severity,
        resolved: false,
        createdAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report submitted')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: _reason,
              items: const [
                'Provider misbehaved',
                'Poor quality of work',
                'Payment issue',
                'Other',
              ]
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => setState(() => _reason = v!),
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Describe what happened',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: ReportSeverity.values
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s.name),
                      selected: _severity == s,
                      onSelected: (_) => setState(() => _severity = s),
                    ),
                  )
                  .toList(),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Submit report',
              loading: _submitting,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
