enum UserRole { customer, provider, admin }

enum ServiceCategory { plumber, electrician, carpenter, unknown }

enum ProblemComplexity { low, medium, high }

enum VerificationStatus { pending, approved, rejected, resubmissionRequested }

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

/// Admin moderation state for a submitted [Report].
enum ReportStatus { open, underReview, resolved, rejected }

/// Direction of a [Rating] — who is rating whom.
enum RatingDirection { customerToProvider, providerToCustomer }

/// Account standing, set by an admin (Module 12).
enum AccountStatus { active, restricted, suspended }

/// Lifecycle of a single provider's candidacy on a ticket (Module 5/6).
enum CandidateStatus { pending, selected, notSelected, rejected, expired }
