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
}

enum PaymentStatus { pending, processing, success, failed }

enum ReportSeverity { low, medium, high }
