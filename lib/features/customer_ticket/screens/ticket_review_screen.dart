import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';

class TicketReviewScreen extends StatefulWidget {
  const TicketReviewScreen({super.key});

  @override
  State<TicketReviewScreen> createState() => _TicketReviewScreenState();
}

class _TicketReviewScreenState extends State<TicketReviewScreen> {
  bool _submitting = false;
  String? _error;

  Future<void> _submit(Map<String, dynamic> args) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final user = await AuthService.instance.currentUser();
      if (user == null) {
        throw StateError('Please sign in before submitting a request.');
      }

      final category = ServiceCategory.values.firstWhere(
        (c) => c.name == (args['category'] ?? ''),
        orElse: () => ServiceCategory.unknown,
      );
      final complexity = ProblemComplexity.values.firstWhere(
        (c) => c.name == (args['complexity'] ?? ''),
        orElse: () => ProblemComplexity.low,
      );
      final draft = Ticket(
        id: '',
        customerId: user.id,
        customerName: user.name ?? '',
        description: args['description']?.toString() ?? '',
        imageUrls: List<String>.from(args['images'] ?? []),
        category: category,
        complexity: complexity,
        approximateLocation: const GeoPoint(0, 0),
        status: TicketStatus.draft,
        createdAt: DateTime.now(),
        addressLine: args['address']?.toString(),
      );

      await TicketService.instance.createTicket(draft);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(RouteNames.matchingProgress);
    } on fs.FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyFirestoreMessage(e));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Bad state: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _friendlyFirestoreMessage(fs.FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Firebase is rejecting ticket creation. Check Firestore rules for the tickets collection and make sure this signed-in customer can create their own request.';
    }
    if (e.code == 'unavailable') {
      return 'Could not reach Firebase. Check your connection and try again.';
    }
    return e.message ?? 'Could not submit the request. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
        const {};
    return Scaffold(
      appBar: AppBar(title: const Text('Review request')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SummaryTile(
              label: 'Category',
              value: args['category']?.toString() ?? '—',
            ),
            _SummaryTile(
              label: 'Complexity',
              value: args['complexity']?.toString() ?? '—',
            ),
            _SummaryTile(
              label: 'Description',
              value: args['description'] ?? '—',
            ),
            _SummaryTile(
              label: 'Location',
              value: args['address'] ?? 'Current',
            ),
            const Spacer(),
            const Text(
              'Your exact address stays private until you confirm a provider.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: AppColors.error)),
              const SizedBox(height: 12),
            ],
            PrimaryButton(
              label: 'Submit request',
              loading: _submitting,
              onPressed: _submitting ? null : () => _submit(args),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      subtitle: Text(value),
      contentPadding: EdgeInsets.zero,
    );
  }
}
