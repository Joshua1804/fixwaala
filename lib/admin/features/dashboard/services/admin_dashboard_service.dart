import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/services/firebase_service.dart';

/// Tickets not yet completed/paid/closed/cancelled/failed — mirrors
/// `Ticket.isActive` in the mobile app's model.
const _activeTicketStatuses = [
  'draft',
  'matching',
  'awaitingCustomerConfirmation',
  'assigned',
  'providerEnRoute',
  'providerArrived',
  'underInspection',
  'awaitingEstimateApproval',
  'inProgress',
];

/// Jobs not yet completed/cancelled — mirrors `Job.isActive`.
const _activeJobStatuses = [
  'assigned',
  'accepted',
  'enRoute',
  'arrived',
  'checkedIn',
  'inspecting',
  'estimateSubmitted',
  'workInProgress',
  'completionRequested',
];

class DashboardStats {
  final int totalCustomers;
  final int totalProviders;
  final int activeTickets;
  final int failedTickets;
  final int activeJobs;
  final int completedJobs;
  final int openReports;
  final int unresolvedSafetyAlerts;
  final int successfulPayments;
  final double totalRevenue;
  final int registeredDevices;

  const DashboardStats({
    required this.totalCustomers,
    required this.totalProviders,
    required this.activeTickets,
    required this.failedTickets,
    required this.activeJobs,
    required this.completedJobs,
    required this.openReports,
    required this.unresolvedSafetyAlerts,
    required this.successfulPayments,
    required this.totalRevenue,
    required this.registeredDevices,
  });
}

/// Platform-wide counts for the dashboard, read via Firestore aggregation
/// queries (`count()`/`sum()`) rather than downloading every document —
/// admin already has unrestricted read on every collection here per
/// `firestore.rules`, so this is purely about not paying to read documents
/// whose content the dashboard doesn't need.
class AdminDashboardService {
  AdminDashboardService._();
  static final AdminDashboardService instance = AdminDashboardService._();

  FirebaseFirestore get _db => FirebaseService.instance.firestore;

  Future<DashboardStats> load() async {
    final results = await Future.wait([
      _db.collection('users').where('role', isEqualTo: 'customer').count().get(),
      _db.collection('users').where('role', isEqualTo: 'provider').count().get(),
      _db
          .collection('tickets')
          .where('status', whereIn: _activeTicketStatuses)
          .count()
          .get(),
      _db.collection('tickets').where('status', isEqualTo: 'failed').count().get(),
      _db.collection('jobs').where('status', whereIn: _activeJobStatuses).count().get(),
      _db.collection('jobs').where('status', isEqualTo: 'completed').count().get(),
      _db.collection('reports').where('status', isEqualTo: 'open').count().get(),
      _db
          .collection('safetyAlerts')
          .where('resolved', isEqualTo: false)
          .count()
          .get(),
      _db
          .collection('payments')
          .where('status', isEqualTo: 'success')
          .aggregate(count(), sum('amount'))
          .get(),
      _db.collection('deviceTokens').count().get(),
    ]);

    final paymentAgg = results[8];

    return DashboardStats(
      totalCustomers: results[0].count ?? 0,
      totalProviders: results[1].count ?? 0,
      activeTickets: results[2].count ?? 0,
      failedTickets: results[3].count ?? 0,
      activeJobs: results[4].count ?? 0,
      completedJobs: results[5].count ?? 0,
      openReports: results[6].count ?? 0,
      unresolvedSafetyAlerts: results[7].count ?? 0,
      successfulPayments: paymentAgg.count ?? 0,
      totalRevenue: paymentAgg.getSum('amount') ?? 0,
      registeredDevices: results[9].count ?? 0,
    );
  }
}
