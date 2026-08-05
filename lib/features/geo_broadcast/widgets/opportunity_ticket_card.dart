import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/utils/eta_estimate.dart';
import '../../auth/services/auth_service.dart';
import '../../customer_ticket/models/ticket_model.dart';
import '../../trust_gated_matching/models/candidate_lease.dart';
import '../../trust_gated_matching/services/matching_service.dart';

/// A single incoming-request card with Accept/Decline, shared by the
/// provider home screen's live preview and the Jobs page's Incoming tab.
class OpportunityTicketCard extends StatefulWidget {
  final Ticket ticket;
  final double distanceKm;
  const OpportunityTicketCard({
    super.key,
    required this.ticket,
    required this.distanceKm,
  });

  @override
  State<OpportunityTicketCard> createState() => _OpportunityTicketCardState();
}

class _OpportunityTicketCardState extends State<OpportunityTicketCard> {
  bool _accepting = false;
  bool _declined = false;

  Future<void> _accept(AppUser? currentProvider) async {
    if (currentProvider == null) {
      // Accepting under the wrong identity would silently fail the
      // Firestore write (candidate docId must equal the accepting
      // provider's own auth uid per firestore.rules) and leave the
      // customer stuck waiting with no candidate ever appearing.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Still loading your account — try again in a moment.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _accepting = true);
    try {
      await MatchingService.instance.acceptOpportunity(
        ticketId: widget.ticket.id,
        providerId: currentProvider.id,
        provider: currentProvider,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accepted — waiting for the customer to confirm.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      // This was `try`/`finally` with no `catch`: a restricted account or any
      // Firestore failure threw straight past the UI, so the provider saw the
      // button re-enable and nothing else, with no idea the accept had failed.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessages.friendly(error)),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  Future<void> _decline(AppUser? currentProvider) async {
    if (currentProvider == null) return;
    await MatchingService.instance.declineOpportunity(
      ticketId: widget.ticket.id,
      providerId: currentProvider.id,
    );
    if (!mounted) return;
    setState(() => _declined = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_declined) return const SizedBox.shrink();
    return FutureBuilder<AppUser?>(
      future: AuthService.instance.currentUser(),
      builder: (context, userSnap) {
        final currentProvider = userSnap.data;
        if (currentProvider == null) {
          return _buildCard(context, currentProvider, null);
        }
        // Reacts to this provider's own candidacy on this ticket, so the
        // card stops offering Accept/Decline the moment they've already
        // acted — previously it kept re-rendering both buttons after a
        // successful accept, and tapping Decline then would flip the
        // provider's own accepted lease to rejected.
        return StreamBuilder<CandidateLease?>(
          stream: MatchingService.instance.watchMyLease(
            widget.ticket.id,
            currentProvider.id,
          ),
          builder: (context, leaseSnap) {
            final lease = leaseSnap.data;
            final settled =
                lease?.status == CandidateStatus.notSelected ||
                lease?.status == CandidateStatus.rejected ||
                lease?.status == CandidateStatus.expired;
            if (settled) return const SizedBox.shrink();
            return _buildCard(context, currentProvider, lease);
          },
        );
      },
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppUser? currentProvider,
    CandidateLease? lease,
  ) {
    final waiting =
        lease?.status == CandidateStatus.pending ||
        lease?.status == CandidateStatus.selected;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.ticket.category.name.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${widget.ticket.createdAt.hour.toString().padLeft(2, '0')}:${widget.ticket.createdAt.minute.toString().padLeft(2, '0')}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Customer: ${widget.ticket.customerName}',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.ticket.description,
            style: AppTextStyles.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.route_outlined,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.distanceKm.toStringAsFixed(1)} km away · '
                '~${EtaEstimate.minutesFor(widget.distanceKm)} min',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          waiting ? _buildWaitingRow() : _buildActionsRow(currentProvider),
        ],
      ),
    );
  }

  Widget _buildWaitingRow() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.hourglass_top_rounded,
            size: 18,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Text(
            'Accepted — waiting for the customer to confirm',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow(AppUser? currentProvider) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _accepting ? null : () => _decline(currentProvider),
            child: const Text('Decline'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _accepting ? null : () => _accept(currentProvider),
            icon: _accepting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_outline, size: 20),
            label: const Text('Accept'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
