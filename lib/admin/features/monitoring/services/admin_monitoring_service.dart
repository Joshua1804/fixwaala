import '../../../../core/services/firebase_service.dart';

class CollectionHealth {
  final String name;
  final int count;
  const CollectionHealth(this.name, this.count);
}

/// Raw operational counts, distinct from the Dashboard's business-framed
/// metrics — this is "is data flowing into every collection", not "how is
/// the business doing".
class AdminMonitoringService {
  AdminMonitoringService._();
  static final AdminMonitoringService instance = AdminMonitoringService._();

  static const _collections = [
    'users',
    'tickets',
    'openTickets',
    'jobs',
    'payments',
    'ratings',
    'reports',
    'safetyAlerts',
    'deviceTokens',
    'announcements',
    'admins',
    'auditEvents',
  ];

  Future<List<CollectionHealth>> load() async {
    final db = FirebaseService.instance.firestore;
    final results = await Future.wait(
      _collections.map((name) => db.collection(name).count().get()),
    );
    return [
      for (var i = 0; i < _collections.length; i++)
        CollectionHealth(_collections[i], results[i].count ?? 0),
    ];
  }
}
