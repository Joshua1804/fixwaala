import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'core/services/app_preferences_service.dart';
import 'core/services/firebase_service.dart';
import 'core/services/notification_service.dart';
import 'features/payment/services/payment_service.dart';
import 'features/ratings/services/rating_service.dart';
import 'features/service_lifecycle/services/job_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('[main] No .env found, AI features will use the rule-based fallback: $e');
  }
  await FirebaseService.instance.initialize();
  await AppPreferencesService.instance.initialize();
  await JobService.instance.initialize();
  await PaymentService.instance.initialize();
  await RatingService.instance.initialize();
  await NotificationService.instance.initialize();
  runApp(const FixwaalaApp());
}
