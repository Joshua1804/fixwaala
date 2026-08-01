import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../ai_assist/models/clarifying_qa.dart';
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

      final location = await LocationService.instance.getCurrentLocation();
      if (location == null) {
        throw StateError(
          'Could not get your location. Please enable location permissions and try again.',
        );
      }

      final category = ServiceCategory.values.firstWhere(
        (c) => c.name == (args['category'] ?? ''),
        orElse: () => ServiceCategory.unknown,
      );
      if (category == ServiceCategory.unknown) {
        throw StateError(
          'Please choose a service category before submitting — this is '
          'how nearby providers find your request.',
        );
      }
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
        approximateLocation: location,
        status: TicketStatus.draft,
        createdAt: DateTime.now(),
        addressLine: args['address']?.toString(),
        aiSummary: args['aiSummary']?.toString(),
        recommendedEquipment: List<String>.from(
          args['recommendedEquipment'] ?? const [],
        ),
        clarifyingQa: (args['clarifyingQa'] as List? ?? const [])
            .map((m) => ClarifyingQa.fromMap(Map<String, dynamic>.from(m)))
            .toList(),
      );

      final ticketId = await TicketService.instance.createTicket(draft);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        RouteNames.matchingProgress,
        arguments: ticketId,
      );
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
            if ((args['aiSummary'] as String?)?.isNotEmpty ?? false)
              _SummaryTile(label: 'AI summary', value: args['aiSummary']),
            _SummaryTile(
              label: 'Location',
              value: args['address'] ?? 'Current',
            ),
            if ((args['images'] as List?)?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              const Text('Photos'),
              const SizedBox(height: 8),
              SizedBox(
                height: 72,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: (args['images'] as List).length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      (args['images'] as List)[i].toString(),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
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
