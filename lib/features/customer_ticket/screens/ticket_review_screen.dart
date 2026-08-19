import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../ai_assist/models/clarifying_qa.dart';
import '../../auth/services/auth_service.dart';
import '../models/ticket_model.dart';
import '../services/ticket_service.dart';
import '../../../core/widgets/remote_image.dart';
import '../../../core/utils/error_messages.dart';

class TicketReviewScreen extends StatefulWidget {
  const TicketReviewScreen({super.key});

  @override
  State<TicketReviewScreen> createState() => _TicketReviewScreenState();
}

class _TicketReviewScreenState extends State<TicketReviewScreen> {
  bool _submitting = false;
  String? _error;

  /// The address detail sent to the assigned provider.
  ///
  /// `args['address']` was read here but nothing in the flow ever set it —
  /// CreateTicket did not collect an address, AiAssist did not forward one,
  /// and [LocationService.reverseGeocode] existed with no callers at all. So
  /// `Ticket.addressLine` was always null and the provider arrived with bare
  /// GPS coordinates: no flat number, no landmark, no gate code.
  final TextEditingController _addressController = TextEditingController();
  bool _addressSeeded = false;
  bool _locating = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  /// Defaults to the address the customer already gave at onboarding.
  Future<void> _seedAddress() async {
    if (_addressSeeded) return;
    _addressSeeded = true;
    final user = await AuthService.instance.currentUser();
    final profile = user?.customerProfile;
    final saved = [
      profile?.addressLine,
      profile?.city,
      profile?.pincode,
    ].where((p) => p != null && p.trim().isNotEmpty).join(', ');
    if (saved.isNotEmpty && mounted) {
      setState(() => _addressController.text = saved);
    }
  }

  /// Fills the field from the device's current position.
  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final point = await LocationService.instance.getCurrentLocation();
      final resolved = point == null
          ? null
          : await LocationService.instance.reverseGeocode(point);
      if (!mounted) return;
      setState(() {
        _locating = false;
        if (resolved != null) {
          _addressController.text = resolved;
        } else {
          _error = 'Could not resolve your address. Please type it in.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locating = false;
        _error = ErrorMessages.friendly(error);
      });
    }
  }

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
        addressLine: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
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
      Navigator.of(
        context,
      ).pushReplacementNamed(RouteNames.matchingProgress, arguments: ticketId);
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
    _seedAddress();
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
            const SizedBox(height: 8),
            TextField(
              controller: _addressController,
              textCapitalization: TextCapitalization.words,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Address details',
                hintText: 'Flat / house number, landmark, gate code',
                border: const OutlineInputBorder(),
                helperText: 'Only shared once you confirm a provider.',
                suffixIcon: IconButton(
                  tooltip: 'Use my current location',
                  icon: _locating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location_rounded),
                  onPressed: _locating ? null : _useCurrentLocation,
                ),
              ),
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
                  itemBuilder: (context, i) => RemoteImage(
                    url: (args['images'] as List)[i].toString(),
                    width: 72,
                    height: 72,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
            const Spacer(),
            const Text(
              'Your exact address stays private until you confirm a provider.',
              style: AppTextStyles.caption,
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
