import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'features/payment/services/payment_service.dart';
import 'features/ratings/services/rating_service.dart';
import 'features/service_lifecycle/services/job_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Configuration arrives via --dart-define, not a bundled .env asset. See
  // docs/CONFIGURATION.md for the required build flags.
  //
  // FirebaseService goes first — every other service below checks
  // FirebaseService.instance.isInitialized to decide live vs. simulation
  // mode, so it can't run concurrently with them. The other four don't
  // depend on each other, so they run in parallel rather than one after
  // another; on a cold start this is the difference between the native
  // launch screen sitting there for the sum of five awaits versus the
  // slowest one, cutting real time-to-first-frame.
  await FirebaseService.instance.initialize();
  await Future.wait([
    AppPreferencesService.instance.initialize(),
    JobService.instance.initialize(),
    PaymentService.instance.initialize(),
    RatingService.instance.initialize(),
    NotificationService.instance.initialize(),
  ]);
  runApp(const FixwaalaApp());
}
