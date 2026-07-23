/// Push + local notifications for opportunities, matching updates, SOS alerts.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> initialize() async {
    // TODO: request FCM permission, register token, wire foreground/background handlers.
  }

  Future<String?> getFcmToken() async {
    // TODO: FirebaseMessaging.instance.getToken()
    return null;
  }

  Future<void> subscribeToTopic(String topic) async {
    // TODO
  }

  Future<void> showLocalAlert({
    required String title,
    required String body,
  }) async {
    // TODO: flutter_local_notifications wire-up.
  }
}
