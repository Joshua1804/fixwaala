import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// In-app local notifications for opportunities and matching updates.
///
/// There is no push backend (no Cloud Functions/FCM), so this stands in for
/// what would otherwise be a push notification — fired locally the moment
/// this device observes a relevant Firestore change. `flutter_local_notifications`
/// has no web implementation, so every method is a no-op on web; the app's
/// own in-app UI (StreamBuilders) covers that platform instead.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'fixwaala_alerts';
  static const _channelName = 'Fixwaala alerts';

  Future<void> initialize() async {
    if (kIsWeb) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
  }) async {
    if (kIsWeb || !_initialized) return;
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }
}
