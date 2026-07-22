import '../../../core/models/enums.dart';

class RepairEstimate {
  final double laborCharge;
  final double partsCharge;
  final String notes;

  const RepairEstimate({
    required this.laborCharge,
    required this.partsCharge,
    required this.notes,
  });

  double get total => laborCharge + partsCharge;
}

class Job {
  final String jobId;
  final String ticketId;
  final String providerId;
  final String customerId;
  final TicketStatus status;
  final RepairEstimate? estimate;
  final DateTime createdAt;

  const Job({
    required this.jobId,
    required this.ticketId,
    required this.providerId,
    required this.customerId,
    required this.status,
    required this.createdAt,
    this.estimate,
  });
}
