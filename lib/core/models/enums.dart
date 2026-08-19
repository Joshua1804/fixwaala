enum UserRole { customer, provider }

enum ServiceCategory { plumber, electrician, carpenter, unknown }

enum ProblemComplexity { low, medium, high }

enum TicketStatus {
  draft,
  matching,
  awaitingCustomerConfirmation,
  assigned,
  providerEnRoute,
  providerArrived,
  underInspection,
  awaitingEstimateApproval,
  inProgress,
  completed,
  paid,
  closed,
  cancelled,
  failed,
}

enum JobEvent {
  travelStarted,
  arrived,
  checkedIn,
  inspectionSubmitted,
  estimateAccepted,
  estimateRejected,
  workStarted,
  workCompleted,
  customerConfirmed,
  jobAccepted,
  jobRejected,
  completionRequested,
  cancelled,
}

/// Granular provider-driven job lifecycle status (Module 7).
///
/// This is distinct from [TicketStatus], which tracks the coarser
/// matching-phase lifecycle. A [Job] only exists once a ticket has an
/// assigned provider (i.e. after Trust-Gated Matching confirms them).
enum JobStatus {
  assigned,
  accepted,
  enRoute,
  arrived,
  checkedIn,
  inspecting,
  estimateSubmitted,
  workInProgress,
  completionRequested,
  completed,
  cancelled,
}

enum PaymentStatus { pending, processing, success, failed }

enum ReportSeverity { low, medium, high }

/// Moderation state for a submitted [Report]. Advanced from the admin website;
/// the app only ever creates reports at [ReportStatus.open].
enum ReportStatus { open, underReview, resolved, rejected }

/// Direction of a [Rating] — who is rating whom.
enum RatingDirection { customerToProvider, providerToCustomer }

/// Account standing. Written by the admin website onto `users/{uid}`; the app
/// only reads it to block actions a non-active account must not perform.
enum AccountStatus { active, restricted, suspended }

/// Lifecycle of a single provider's candidacy on a ticket (Module 5/6).
enum CandidateStatus { pending, selected, notSelected, rejected, expired }

/// Firestore can hand back an enum string a build doesn't recognise — a
/// renamed case, a hand-edited document, a partially-migrated field.
/// `.byName` throws on any mismatch and takes the whole document read down
/// with it; this falls back to a caller-supplied default instead.
extension EnumByNameSafe<T extends Enum> on List<T> {
  T byNameOrDefault(String? name, T fallback) {
    if (name == null) return fallback;
    for (final value in this) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
