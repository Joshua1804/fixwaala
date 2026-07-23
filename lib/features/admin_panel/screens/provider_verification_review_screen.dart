import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../services/admin_service.dart';

class ProviderVerificationReviewScreen extends StatelessWidget {
  const ProviderVerificationReviewScreen({super.key});

  Future<void> _decide(
    BuildContext context,
    String providerId,
    VerificationStatus decision,
  ) async {
    await AdminService.instance.reviewProviderVerification(
      providerId: providerId,
      decision: decision,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Marked ${decision.name}')));
  }

  @override
  Widget build(BuildContext context) {
    // TODO: replace with StreamBuilder over Firestore pending queue.
    final providers = List.generate(
      3,
      (i) => {
        'id': 'p$i',
        'name': 'Provider ${i + 1}',
        'aadhaar': 'XXXX-XXXX-12$i',
        'selfie': 'https://placeholder/selfie$i.jpg',
      },
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Verifications')),
      body: ListView.separated(
        itemCount: providers.length,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, i) {
          final p = providers[i];
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(p['name']!),
            subtitle: Text('Aadhaar ${p['aadhaar']}'),
            trailing: PopupMenuButton<VerificationStatus>(
              onSelected: (v) => _decide(context, p['id']!, v),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: VerificationStatus.approved,
                  child: Text('Approve'),
                ),
                PopupMenuItem(
                  value: VerificationStatus.resubmissionRequested,
                  child: Text('Request resubmission'),
                ),
                PopupMenuItem(
                  value: VerificationStatus.rejected,
                  child: Text('Reject'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
