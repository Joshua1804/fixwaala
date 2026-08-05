import 'package:flutter/material.dart';

import '../../features/customer_ticket/services/ticket_service.dart';
import '../theme/app_colors.dart';
import '../utils/error_messages.dart';

/// Confirms and performs a customer's cancellation of a request.
///
/// `TicketService.cancelTicket()` existed with **zero callers**. The matching
/// screen's "Cancel" button only called `Navigator.pop`, so the ticket stayed
/// in `matching` and kept broadcasting to providers after the customer
/// believed they had withdrawn it. There was no cancel action anywhere else at
/// all — not on the ticket card, not in My Tickets, not on job tracking.
class CancelRequestAction {
  CancelRequestAction._();

  /// Asks for confirmation, then cancels. Returns true if the ticket was
  /// cancelled, so the caller can navigate away.
  static Future<bool> run(
    BuildContext context, {
    required String ticketId,
    String message =
        'This request will stop being sent to providers. You can always create a new one.',
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep searching'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed != true) return false;

    try {
      await TicketService.instance.cancelTicket(ticketId);
      return true;
    } catch (error) {
      if (!context.mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(error))));
      return false;
    }
  }
}
