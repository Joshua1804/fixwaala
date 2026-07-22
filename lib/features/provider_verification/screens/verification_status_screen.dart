import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../auth/services/auth_service.dart';
import '../services/verification_service.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification status')),
      body: FutureBuilder<AppUser?>(
        future: AuthService.instance.currentUser(),
        builder: (context, userSnapshot) {
          final user = userSnapshot.data;
          final uid = user?.id ?? 'mock-provider-id';
          return FutureBuilder<VerificationStatus>(
            future: VerificationService.instance.status(uid),
            builder: (context, snapshot) {
              final status = snapshot.data ?? VerificationStatus.pending;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(_iconFor(status), size: 72, color: _colorFor(status)),
                    const SizedBox(height: 16),
                    Text(_labelFor(status),
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    const Text(
                        'Admin will review your verification shortly. You can go online once approved.'),
                    const Spacer(),
                    if (status == VerificationStatus.approved)
                      FilledButton(
                        onPressed: () => Navigator.of(context)
                            .pushReplacementNamed(RouteNames.providerHome),
                        child: const Text('Go to dashboard'),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconFor(VerificationStatus s) => switch (s) {
        VerificationStatus.approved => Icons.verified,
        VerificationStatus.rejected => Icons.cancel,
        VerificationStatus.resubmissionRequested => Icons.refresh,
        VerificationStatus.pending => Icons.hourglass_top,
      };

  Color _colorFor(VerificationStatus s) => switch (s) {
        VerificationStatus.approved => Colors.green,
        VerificationStatus.rejected => Colors.red,
        VerificationStatus.resubmissionRequested => Colors.orange,
        VerificationStatus.pending => Colors.blueGrey,
      };

  String _labelFor(VerificationStatus s) => switch (s) {
        VerificationStatus.approved => 'Verified',
        VerificationStatus.rejected => 'Rejected',
        VerificationStatus.resubmissionRequested => 'Please resubmit',
        VerificationStatus.pending => 'Pending review',
      };
}
