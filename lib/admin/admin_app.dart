import 'package:flutter/material.dart';

import 'core/admin_auth_gate.dart';
import 'core/admin_router.dart';
import 'core/admin_theme.dart';

class FixwaalaAdminApp extends StatelessWidget {
  const FixwaalaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fixwaala Admin',
      debugShowCheckedModeBanner: false,
      // Forced light, not ThemeMode.system: the admin website was rendering
      // dark for any admin whose OS/browser prefers dark, which looked
      // inconsistent with the mobile app's light-by-default styling. The
      // mobile app's theme is a user preference (AppPreferencesService);
      // the admin website has no equivalent toggle, so it always matches
      // the mobile app's default instead.
      theme: AdminTheme.light,
      themeMode: ThemeMode.light,
      home: const AdminAuthGate(),
      onGenerateRoute: AdminRouter.onGenerateRoute,
    );
  }
}
