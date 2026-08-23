// Ported from lib/core/models/enums.dart

export type UserRole = 'customer' | 'provider'

export type ServiceCategory = 'plumber' | 'electrician' | 'carpenter' | 'unknown'

export type TicketStatus =
  | 'draft'
  | 'matching'
  | 'awaitingCustomerConfirmation'
  | 'assigned'
  | 'providerEnRoute'
  | 'providerArrived'
  | 'underInspection'
  | 'awaitingEstimateApproval'
  | 'inProgress'
  | 'completed'
  | 'paid'
  | 'closed'
  | 'cancelled'
  | 'failed'

export type JobStatus =
  | 'assigned'
  | 'accepted'
  | 'enRoute'
  | 'arrived'
  | 'checkedIn'
  | 'inspecting'
  | 'estimateSubmitted'
  | 'workInProgress'
  | 'completionRequested'
  | 'completed'
  | 'cancelled'

export type PaymentStatus = 'pending' | 'processing' | 'success' | 'failed'

export type ReportSeverity = 'low' | 'medium' | 'high'

/** Moderation state for a submitted report. The app only ever creates reports at 'open'; the rest are set from this admin app. */
export type ReportStatus = 'open' | 'underReview' | 'resolved' | 'rejected'

export type RatingDirection = 'customerToProvider' | 'providerToCustomer'

/** Account standing. Written by this admin app onto users/{uid}. */
export type AccountStatus = 'active' | 'restricted' | 'suspended'

export type AnnouncementPriority = 'info' | 'warning' | 'critical'
export type AnnouncementAudience = 'all' | 'customer' | 'provider'

/**
 * Firestore can hand back a string a build doesn't recognise — a renamed
 * case, a hand-edited document, a partially-migrated field. Falls back to a
 * caller-supplied default instead of throwing, mirroring
 * `EnumByNameSafe.byNameOrDefault` in lib/core/models/enums.dart.
 */
export function enumOrDefault<T extends string>(
  allowed: readonly T[],
  value: string | null | undefined,
  fallback: T,
): T {
  if (value != null && (allowed as readonly string[]).includes(value)) {
    return value as T
  }
  return fallback
}
