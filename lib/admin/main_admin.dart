import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import '../core/services/firebase_service.dart';
import 'admin_app.dart';

/// Entry point for the admin website — a separate compilation unit from the
/// mobile app's `lib/main.dart`. Run it with:
///
/// ```
/// flutter run -t lib/admin/main_admin.dart -d chrome
/// ```
///
/// See docs/ADMIN_WEB.md for the full setup (granting the first admin
/// account, etc.) — an admin login is useless until at least one account
/// holds the `admin` custom claim, which only
/// `scripts/admin/grant_admin_claim.js` can grant.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await FirebaseService.instance.initialize();
  runApp(
    FirebaseService.instance.isInitialized
        ? const FixwaalaAdminApp()
        : const _AdminBootFailureApp(),
  );
}

/// Unlike the mobile app, there is no simulation-mode fallback here — an
/// admin tool with nothing real to administer has no reason to exist. If
/// Firebase failed to initialize, say so plainly instead of opening a login
/// screen that can only ever fail.
class _AdminBootFailureApp extends StatelessWidget {
  const _AdminBootFailureApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixwaala Admin',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 40, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Firebase failed to initialize',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  FirebaseService.instance.simulationReason ?? 'Unknown error.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
