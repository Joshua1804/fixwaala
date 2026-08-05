import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../models/job_model.dart';
import '../services/job_service.dart';
import '../../../core/widgets/missing_route_argument_screen.dart';

/// Provider's Inspection and Estimate Screen — where the diagnosis and
/// itemised repair estimate are entered before the customer reviews them.
class ProviderInspectionEstimateScreen extends StatefulWidget {
  final String? jobId;
  const ProviderInspectionEstimateScreen({super.key, this.jobId});

  @override
  State<ProviderInspectionEstimateScreen> createState() =>
      _ProviderInspectionEstimateScreenState();
}

class _ProviderInspectionEstimateScreenState
    extends State<ProviderInspectionEstimateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosisController = TextEditingController();
  final _laborController = TextEditingController();
  final _partsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _submitting = false;
  String? _error;

  /// Empty when this route was opened without a job id — [build] guards on
  /// it and shows a real message. This used to be
  /// `ModalRoute.of(context)!.settings.arguments as String`, which threw on
  /// both the `!` and the cast, so arriving here from a notification tap or a
  /// restored navigation stack crashed the screen.
  String _resolveJobId(BuildContext context) =>
      widget.jobId ??
      ModalRoute.of(context)?.settings.arguments as String? ??
      '';

  @override
  void dispose() {
    _diagnosisController.dispose();
    _laborController.dispose();
    _partsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit(String jobId) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await JobService.instance.submitEstimate(
        jobId,
        RepairEstimate(
          diagnosis: _diagnosisController.text.trim(),
          laborCharge: double.parse(_laborController.text),
          partsCharge: double.parse(_partsController.text),
          notes: _notesController.text.trim(),
          submittedAt: DateTime.now(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _money(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(v);
    if (parsed == null || parsed < 0) return 'Enter a valid amount';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final jobId = _resolveJobId(context);
    if (jobId.isEmpty) {
      return const MissingRouteArgumentScreen(title: 'Inspection & estimate');
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Inspection & estimate')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _diagnosisController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Diagnosis',
                  hintText: 'What did you find?',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Diagnosis is required'
                    : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _laborController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Labour charge (₹)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _money,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _partsController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Parts charge (₹)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _money,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.error)),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Submit estimate',
                loading: _submitting,
                onPressed: _submitting ? null : () => _submit(jobId),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
