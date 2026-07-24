import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';

/// Central place for how a [TicketStatus] is labelled and colored.
///
/// Mirrors [JobStatusUi]'s role for the job lifecycle. Reused by the
/// customer home screen's ticket cards and the My Tickets screen so the
/// status vocabulary reads identically everywhere.
class TicketStatusUi {
  TicketStatusUi._();

  static Color color(TicketStatus status) => switch (status) {
    TicketStatus.draft => AppColors.textHint,
    TicketStatus.matching => AppColors.info,
    TicketStatus.awaitingCustomerConfirmation => AppColors.warning,
    TicketStatus.assigned => AppColors.primary,
    TicketStatus.providerEnRoute => AppColors.primary,
    TicketStatus.providerArrived => AppColors.primary,
    TicketStatus.underInspection => AppColors.primary,
    TicketStatus.awaitingEstimateApproval => AppColors.warning,
    TicketStatus.inProgress => AppColors.primary,
    TicketStatus.completed => AppColors.success,
    TicketStatus.paid => AppColors.success,
    TicketStatus.closed => AppColors.textHint,
    TicketStatus.cancelled => AppColors.error,
    TicketStatus.failed => AppColors.error,
  };

  static String label(TicketStatus status) => switch (status) {
    TicketStatus.draft => 'Draft',
    TicketStatus.matching => 'Finding Provider',
    TicketStatus.awaitingCustomerConfirmation => 'Awaiting Confirmation',
    TicketStatus.assigned => 'Assigned',
    TicketStatus.providerEnRoute => 'En Route',
    TicketStatus.providerArrived => 'Arrived',
    TicketStatus.underInspection => 'Inspecting',
    TicketStatus.awaitingEstimateApproval => 'Estimate Sent',
    TicketStatus.inProgress => 'In Progress',
    TicketStatus.completed => 'Completed',
    TicketStatus.paid => 'Paid',
    TicketStatus.closed => 'Closed',
    TicketStatus.cancelled => 'Cancelled',
    TicketStatus.failed => 'Failed',
  };
}
