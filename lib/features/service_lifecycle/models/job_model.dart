import '../../../core/models/enums.dart';

/// A provider-submitted diagnosis + cost breakdown for a repair.
class RepairEstimate {
  final String diagnosis;
  final double laborCharge;
  final double partsCharge;
  final String notes;
  final DateTime submittedAt;

  const RepairEstimate({
    required this.diagnosis,
    required this.laborCharge,
    required this.partsCharge,
    required this.submittedAt,
    this.notes = '',
  });

  double get total => laborCharge + partsCharge;
}

/// A single timestamped entry in a job's status history.
///
/// Used to derive analytics such as response time (assigned → accepted)
/// and arrival time (en route → arrived).
class JobEventLogEntry {
  final JobEvent event;
  final DateTime timestamp;

  const JobEventLogEntry(this.event, this.timestamp);
}

/// The full lifecycle record of a confirmed service job (Module 7).
///
/// Created the moment a customer confirms a provider in Trust-Gated
/// Matching (Module 6), and closed once payment and both ratings are done.
class Job {
  final String jobId;
  final String ticketId;
  final String providerId;
  final String providerName;
  final String customerId;
  final String customerName;
  final ServiceCategory category;
  final JobStatus status;
  final RepairEstimate? estimate;
  final String? estimateRejectionReason;
  final String? cancellationReason;
  final List<JobEventLogEntry> history;
  final bool hasOpenReport;
  final bool hasSafetyAlert;
  final bool paid;
  final String? paymentId;
  final bool customerRated;
  final bool providerRated;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? enRouteAt;
  final DateTime? arrivedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;

  const Job({
    required this.jobId,
    required this.ticketId,
    required this.providerId,
    required this.providerName,
    required this.customerId,
    required this.customerName,
    required this.category,
    required this.status,
    required this.history,
    required this.createdAt,
    this.estimate,
    this.estimateRejectionReason,
    this.cancellationReason,
    this.hasOpenReport = false,
    this.hasSafetyAlert = false,
    this.paid = false,
    this.paymentId,
    this.customerRated = false,
    this.providerRated = false,
    this.acceptedAt,
    this.enRouteAt,
    this.arrivedAt,
    this.completedAt,
    this.closedAt,
  });

  Job copyWith({
    JobStatus? status,
    RepairEstimate? estimate,
    String? estimateRejectionReason,
    String? cancellationReason,
    List<JobEventLogEntry>? history,
    bool? hasOpenReport,
    bool? hasSafetyAlert,
    bool? paid,
    String? paymentId,
    bool? customerRated,
    bool? providerRated,
    DateTime? acceptedAt,
    DateTime? enRouteAt,
    DateTime? arrivedAt,
    DateTime? completedAt,
    DateTime? closedAt,
  }) {
    return Job(
      jobId: jobId,
      ticketId: ticketId,
      providerId: providerId,
      providerName: providerName,
      customerId: customerId,
      customerName: customerName,
      category: category,
      status: status ?? this.status,
      estimate: estimate ?? this.estimate,
      estimateRejectionReason:
          estimateRejectionReason ?? this.estimateRejectionReason,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      history: history ?? this.history,
      createdAt: createdAt,
      hasOpenReport: hasOpenReport ?? this.hasOpenReport,
      hasSafetyAlert: hasSafetyAlert ?? this.hasSafetyAlert,
      paid: paid ?? this.paid,
      paymentId: paymentId ?? this.paymentId,
      customerRated: customerRated ?? this.customerRated,
      providerRated: providerRated ?? this.providerRated,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      enRouteAt: enRouteAt ?? this.enRouteAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      completedAt: completedAt ?? this.completedAt,
      closedAt: closedAt ?? this.closedAt,
    );
  }

  /// Time between the job being assigned and the provider accepting it.
  Duration? get responseTime => acceptedAt?.difference(createdAt);

  /// Time between the provider starting travel and arriving.
  Duration? get arrivalTime => (enRouteAt == null || arrivedAt == null)
      ? null
      : arrivedAt!.difference(enRouteAt!);

  bool get isActive =>
      status != JobStatus.completed && status != JobStatus.cancelled;

  bool get isTerminal => !isActive;

  /// True once payment succeeded and both parties have rated each other —
  /// the point at which the ticket is fully closed.
  bool get isFullyClosed => closedAt != null;

  /// Whether the customer still owes an action to move this job forward.
  bool get needsCustomerAction =>
      status == JobStatus.estimateSubmitted ||
      status == JobStatus.completionRequested ||
      (status == JobStatus.completed && !paid) ||
      (paid && !customerRated);
}
