import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/verification_service.dart';

class SelfieCaptureScreen extends StatefulWidget {
  const SelfieCaptureScreen({super.key});

  @override
  State<SelfieCaptureScreen> createState() => _SelfieCaptureScreenState();
}

class _SelfieCaptureScreenState extends State<SelfieCaptureScreen> {
  String? _localPath;
  bool _uploading = false;

  Future<void> _captureSelfie() async {
    // TODO: open camera via `camera` / `image_picker` package.
    setState(() => _localPath = '/tmp/selfie.jpg');
  }

  Future<void> _submit() async {
    if (_localPath == null) return;
    setState(() => _uploading = true);
    final url = await VerificationService.instance.uploadSelfie(_localPath!);
    await VerificationService.instance.runSelfieChecks(
      selfieUrl: url,
      referenceImageUrl: null,
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    Navigator.of(context).pushReplacementNamed(RouteNames.verificationStatus);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Selfie verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 3 / 4,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _localPath == null
                    ? const Center(child: Icon(Icons.camera_alt, size: 64))
                    : const Center(
                        child: Icon(
                          Icons.check_circle,
                          size: 64,
                          color: AppColors.success,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _captureSelfie,
              icon: const Icon(Icons.camera_alt),
              label: Text(_localPath == null ? 'Capture selfie' : 'Retake'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Submit for verification',
              loading: _uploading,
              onPressed: _localPath == null ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
