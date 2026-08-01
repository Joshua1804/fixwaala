import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../customer_ticket/services/ticket_service.dart';
import '../models/candidate_lease.dart';
import '../services/matching_service.dart';

/// Customer-facing candidate review screen.
///
/// Every provider who has accepted the ticket shows up here, live, with a
/// shared countdown drawn from the ticket's `candidateWindowExpiresAt`. The
/// customer verifies credentials and confirms one — only then is the exact
/// address revealed to that provider. This is the core Trust-Gated
/// Matching UI (Module 6).
class ProviderReviewScreen extends StatefulWidget {
  const ProviderReviewScreen({super.key});

  @override
  State<ProviderReviewScreen> createState() => _ProviderReviewScreenState();
}

class _ProviderReviewScreenState extends State<ProviderReviewScreen> {
  Timer? _timer;
  bool _expiredHandled = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _ensureTimer(String ticketId, DateTime? expiresAt) {
    if (_timer != null || expiresAt == null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!DateTime.now().isBefore(expiresAt)) {
        _timer?.cancel();
        _handleExpired(ticketId);
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _handleExpired(String ticketId) async {
    if (_expiredHandled) return;
    _expiredHandled = true;
    final candidates = await MatchingService.instance
        .watchCandidates(ticketId)
        .first;
    for (final c in candidates.where(
      (c) => c.status == CandidateStatus.pending,
    )) {
      await MatchingService.instance.rejectCandidate(
        ticketId: ticketId,
        providerId: c.providerId,
        status: CandidateStatus.expired,
      );
    }
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacementNamed(RouteNames.matchingProgress, arguments: ticketId);
  }

  Future<void> _confirm(CandidateLease candidate) async {
    _timer?.cancel();
    await MatchingService.instance.confirmProvider(
      ticketId: candidate.ticketId,
      providerId: candidate.providerId,
      providerName: candidate.displayName,
      category: candidate.category,
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(RouteNames.jobTracking);
  }

  @override
  Widget build(BuildContext context) {
    final ticketId = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: const Text('Review providers')),
      body: StreamBuilder<Ticket>(
        stream: TicketService.instance.watchTicket(ticketId),
        builder: (context, ticketSnap) {
          if (!ticketSnap.hasData) {
            return const LoadingWidget(label: 'Loading...');
          }
          final ticket = ticketSnap.data!;
          _ensureTimer(ticketId, ticket.candidateWindowExpiresAt);

          const totalSeconds = AppConstants.candidateReviewSeconds;
          final remainingSeconds = ticket.candidateWindowExpiresAt == null
              ? totalSeconds
              : ticket.candidateWindowExpiresAt!
                    .difference(DateTime.now())
                    .inSeconds
                    .clamp(0, totalSeconds);

          return StreamBuilder<List<CandidateLease>>(
            stream: MatchingService.instance.watchCandidates(ticketId),
            builder: (context, candSnap) {
              final candidates = (candSnap.data ?? [])
                  .where((c) => c.status == CandidateStatus.pending)
                  .toList();

              return Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          candidates.length == 1
                              ? '1 provider available'
                              : '${candidates.length} providers available',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${remainingSeconds}s',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: remainingSeconds / totalSeconds,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your exact address is only shared with the provider you confirm.',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: candidates.isEmpty
                          ? const Center(
                              child: Text(
                                'Waiting for a provider to accept...',
                              ),
                            )
                          : ListView.separated(
                              itemCount: candidates.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) => _CandidateCard(
                                candidate: candidates[i],
                                onConfirm: () => _confirm(candidates[i]),
                              ),
                            ),
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
}

class _CandidateCard extends StatelessWidget {
  final CandidateLease candidate;
  final VoidCallback onConfirm;
  const _CandidateCard({required this.candidate, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    _initials(candidate.displayName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        candidate.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (candidate.verified)
                        const Row(
                          children: [
                            Icon(
                              Icons.verified,
                              size: 14,
                              color: AppColors.success,
                            ),
                            SizedBox(width: 4),
                            Text('Aadhaar + Selfie verified'),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _Stat(
                  icon: Icons.star,
                  label: candidate.ratingAverage.toStringAsFixed(1),
                ),
                _Stat(
                  icon: Icons.work_history,
                  label: '${candidate.completedJobs} jobs',
                ),
                _Stat(
                  icon: Icons.route,
                  label: '${candidate.distanceKm.toStringAsFixed(1)} km',
                ),
                _Stat(icon: Icons.timer, label: '${candidate.etaMinutes} min'),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.person_outline_rounded, size: 18),
              label: const Text('View full profile'),
              onPressed: () => Navigator.of(context).pushNamed(
                RouteNames.candidateProviderProfile,
                arguments: candidate.providerId,
              ),
            ),
            const SizedBox(height: 8),
            PrimaryButton(label: 'Confirm this provider', onPressed: onConfirm),
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

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
      .toUpperCase();
}
