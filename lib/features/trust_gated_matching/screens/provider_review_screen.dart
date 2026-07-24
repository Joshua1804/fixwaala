import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../../auth/services/auth_service.dart';
import '../services/matching_service.dart';

/// Customer-facing 30-second review screen.
///
/// The customer verifies provider credentials before their exact address is
/// revealed to anyone. This is the core Trust-Gated Matching UI.
class ProviderReviewScreen extends StatefulWidget {
  const ProviderReviewScreen({super.key});

  @override
  State<ProviderReviewScreen> createState() => _ProviderReviewScreenState();
}

class _ProviderReviewScreenState extends State<ProviderReviewScreen> {
  late Timer _timer;
  int _remaining = AppConstants.candidateReviewSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remaining -= 1);
      if (_remaining <= 0) {
        _timer.cancel();
        _handleExpired();
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<void> _handleExpired() async {
    await MatchingService.instance.rejectCandidate(
      ticketId: 'ticket-id-stub',
      providerId: 'provider-id-stub',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RouteNames.matchingProgress);
  }

  Future<void> _confirm() async {
    _timer.cancel();
    final activeProvider = MatchingService.instance.activeProvider;
    final providerName = activeProvider?.name ?? 'Joshua George';
    final providerId = activeProvider?.id ?? AppConstants.demoProviderId;
    await MatchingService.instance.confirmProvider(
      ticketId: 'ticket-id-stub',
      providerId: providerId,
      providerName: providerName,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RouteNames.jobTracking);
  }

  Future<void> _reject() async {
    _timer.cancel();
    await MatchingService.instance.rejectCandidate(
      ticketId: 'ticket-id-stub',
      providerId: 'provider-id-stub',
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RouteNames.matchingProgress);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review provider'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                '${_remaining}s',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _ProviderCard(),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _remaining / AppConstants.candidateReviewSeconds,
            ),
            const SizedBox(height: 12),
            const Text(
              'Your exact address is only shared after you confirm.',
              style: TextStyle(fontSize: 12),
            ),
            const Spacer(),
            PrimaryButton(label: 'Confirm provider', onPressed: _confirm),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _reject,
              child: const Text('Reject and find another'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard();

  @override
  Widget build(BuildContext context) {
    final activeProvider = MatchingService.instance.activeProvider;
    final providerName = activeProvider?.name ?? 'Joshua George';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(radius: 28, child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.verified, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Aadhaar + Selfie verified'),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(icon: Icons.star, label: '4.8'),
                _Stat(icon: Icons.work_history, label: '132 jobs'),
                _Stat(icon: Icons.route, label: '1.2 km'),
                _Stat(icon: Icons.timer, label: '8 min'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Stat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [Icon(icon), const SizedBox(height: 4), Text(label)],
    );
  }
}
