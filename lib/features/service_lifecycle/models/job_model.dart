import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import '../../../core/models/enums.dart';

DateTime _dateFromAny(dynamic value) {
  if (value is fs.Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
}

DateTime? _dateFromAnyOrNull(dynamic value) {
  if (value == null) return null;
  return _dateFromAny(value);
}

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

  Map<String, dynamic> toMap() => {
    'diagnosis': diagnosis,
    'laborCharge': laborCharge,
    'partsCharge': partsCharge,
    'notes': notes,
    'submittedAt': fs.Timestamp.fromDate(submittedAt),
  };

  factory RepairEstimate.fromMap(Map<String, dynamic> map) => RepairEstimate(
    diagnosis: map['diagnosis'] as String? ?? '',
    laborCharge: (map['laborCharge'] as num?)?.toDouble() ?? 0,
    partsCharge: (map['partsCharge'] as num?)?.toDouble() ?? 0,
    notes: map['notes'] as String? ?? '',
    submittedAt: _dateFromAny(map['submittedAt']),
  );
}

/// A single timestamped entry in a job's status history.
///
/// Used to derive analytics such as response time (assigned → accepted)
/// and arrival time (en route → arrived).
class JobEventLogEntry {
  final JobEvent event;
  final DateTime timestamp;

  const JobEventLogEntry(this.event, this.timestamp);

  Map<String, dynamic> toMap() => {
    'event': event.name,
    'timestamp': fs.Timestamp.fromDate(timestamp),
  };

  factory JobEventLogEntry.fromMap(Map<String, dynamic> map) =>
      JobEventLogEntry(
        JobEvent.values.byName(map['event'] as String),
        _dateFromAny(map['timestamp']),
      );
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

  Map<String, dynamic> toMap() => {
    'jobId': jobId,
    'ticketId': ticketId,
    'providerId': providerId,
    'providerName': providerName,
    'customerId': customerId,
    'customerName': customerName,
    'category': category.name,
    'status': status.name,
    if (estimate != null) 'estimate': estimate!.toMap(),
    if (estimateRejectionReason != null)
      'estimateRejectionReason': estimateRejectionReason,
    if (cancellationReason != null) 'cancellationReason': cancellationReason,
    'history': history.map((e) => e.toMap()).toList(),
    'hasOpenReport': hasOpenReport,
    'hasSafetyAlert': hasSafetyAlert,
    'paid': paid,
    if (paymentId != null) 'paymentId': paymentId,
    'customerRated': customerRated,
    'providerRated': providerRated,
    'createdAt': fs.Timestamp.fromDate(createdAt),
    if (acceptedAt != null) 'acceptedAt': fs.Timestamp.fromDate(acceptedAt!),
    if (enRouteAt != null) 'enRouteAt': fs.Timestamp.fromDate(enRouteAt!),
    if (arrivedAt != null) 'arrivedAt': fs.Timestamp.fromDate(arrivedAt!),
    if (completedAt != null)
      'completedAt': fs.Timestamp.fromDate(completedAt!),
    if (closedAt != null) 'closedAt': fs.Timestamp.fromDate(closedAt!),
  };

  factory Job.fromMap(Map<String, dynamic> map) => Job(
    jobId: map['jobId'] as String,
    ticketId: map['ticketId'] as String? ?? '',
    providerId: map['providerId'] as String? ?? '',
    providerName: map['providerName'] as String? ?? '',
    customerId: map['customerId'] as String? ?? '',
    customerName: map['customerName'] as String? ?? '',
    category: ServiceCategory.values.byName(
      map['category'] as String? ?? 'unknown',
    ),
    status: JobStatus.values.byName(map['status'] as String? ?? 'assigned'),
    estimate: map['estimate'] != null
        ? RepairEstimate.fromMap(Map<String, dynamic>.from(map['estimate']))
        : null,
    estimateRejectionReason: map['estimateRejectionReason'] as String?,
    cancellationReason: map['cancellationReason'] as String?,
    history: (map['history'] as List<dynamic>? ?? [])
        .map((e) => JobEventLogEntry.fromMap(Map<String, dynamic>.from(e)))
        .toList(),
    hasOpenReport: map['hasOpenReport'] as bool? ?? false,
    hasSafetyAlert: map['hasSafetyAlert'] as bool? ?? false,
    paid: map['paid'] as bool? ?? false,
    paymentId: map['paymentId'] as String?,
    customerRated: map['customerRated'] as bool? ?? false,
    providerRated: map['providerRated'] as bool? ?? false,
    createdAt: _dateFromAny(map['createdAt']),
    acceptedAt: _dateFromAnyOrNull(map['acceptedAt']),
    enRouteAt: _dateFromAnyOrNull(map['enRouteAt']),
    arrivedAt: _dateFromAnyOrNull(map['arrivedAt']),
    completedAt: _dateFromAnyOrNull(map['completedAt']),
    closedAt: _dateFromAnyOrNull(map['closedAt']),
  );

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
