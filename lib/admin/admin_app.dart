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
<<<<<<< HEAD
      // Forced light, not ThemeMode.system: the admin website was rendering
      // dark for any admin whose OS/browser prefers dark, which looked
      // inconsistent with the mobile app's light-by-default styling. The
      // mobile app's theme is a user preference (AppPreferencesService);
      // the admin website has no equivalent toggle, so it always matches
      // the mobile app's default instead.
=======
      // Pinned to light regardless of the browser/OS color-scheme
      // preference — an admin dashboard flipping to `AdminTheme.dark` on a
      // dark-mode machine looked nothing like the mobile app's light theme,
      // which is the visual identity this is meant to share. `AdminTheme.dark`
      // is left in place rather than deleted in case a toggle is added later.
>>>>>>> 7c3ca34f2a4476ef41b965b4e90fa96dfe68fe9c
      theme: AdminTheme.light,
      themeMode: ThemeMode.light,
      home: const AdminAuthGate(),
      onGenerateRoute: AdminRouter.onGenerateRoute,
    );
  }
}
