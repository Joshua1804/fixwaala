import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/services/location_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../customer_ticket/models/ticket_model.dart';
import 'opportunity_ticket_card.dart';

/// The "who's asking for help nearby" card list — shared by the provider
/// home screen (a capped preview) and the Jobs page's Incoming tab (the
/// full list). Takes an already-fetched ticket list rather than owning its
/// own stream, since callers may need the raw list for other purposes (the
/// home screen uses it to drive new-ticket notifications).
class IncomingRequestsSection extends StatelessWidget {
  final List<Ticket> tickets;
  final GeoPoint providerLocation;
  final Object? error;
  final int? limit;
  final VoidCallback? onViewAll;

  const IncomingRequestsSection({
    super.key,
    required this.tickets,
    required this.providerLocation,
    this.error,
    this.limit,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final cap = limit;
    final visible = cap != null && tickets.length > cap
        ? tickets.take(cap).toList()
        : tickets;
    final hiddenCount = tickets.length - visible.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Incoming Service Requests', style: AppTextStyles.titleLarge),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${tickets.length} LIVE',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (error != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Could not load requests: $error',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          )
        else if (tickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Waiting for customer requests nearby...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          ...visible.map(
            (ticket) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: OpportunityTicketCard(
                ticket: ticket,
                distanceKm: LocationService.instance.distanceKm(
                  providerLocation,
                  ticket.approximateLocation,
                ),
              ),
            ),
          ),
          if (hiddenCount > 0 && onViewAll != null)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onViewAll,
                child: Text('View all $hiddenCount more in Jobs'),
              ),
            ),
        ],
      ],
    );
  }
}

/// Explains why the opportunity feed is empty, and offers the fix.
class ProviderDiagnostic extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ProviderDiagnostic({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (actionLabel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(onPressed: onAction, child: Text(actionLabel!)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
