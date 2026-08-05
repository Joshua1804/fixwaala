import '../../features/auth/services/auth_service.dart';
import '../../features/geo_broadcast/services/provider_presence_service.dart';
import '../../features/payment/services/payment_service.dart';
import '../../features/ratings/services/rating_service.dart';
import '../../features/service_lifecycle/services/job_service.dart';
import 'account_service.dart';
import 'notification_service.dart';

/// Ends a signed-in session everywhere at once.
///
/// Sign Out used to be `Navigator.pushReplacementNamed(roleSelection)` and
/// nothing else — the Firebase session, the cached user, and every Firestore
/// listener stayed alive, so relaunching the app (or navigating back) dropped
/// straight into the previous account.
///
/// Order matters: take the provider offline and drop the local caches while
/// credentials are still valid, then release the Firebase session last.
class SessionTeardown {
  SessionTeardown._();

  static Future<void> run() async {
    // Stop advertising availability before the credentials go away, so a
    // signed-out provider cannot keep receiving job broadcasts or streaming
    // their live location.
    await ProviderPresenceService.instance.stopSharing();
    await ProviderPresenceService.instance.setOnline(false);

    // Drop this device's push token before the session ends, so the next
    // person to use the phone does not receive the previous user's jobs.
    await NotificationService.instance.unregisterDevice();

    await JobService.instance.endSession();
    await PaymentService.instance.endSession();
    await RatingService.instance.endSession();
    AccountService.instance.clear();

    await AuthService.instance.signOut();
  }
}
