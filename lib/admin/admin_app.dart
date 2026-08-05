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
      theme: AdminTheme.light,
      darkTheme: AdminTheme.dark,
      themeMode: ThemeMode.system,
      home: const AdminAuthGate(),
      onGenerateRoute: AdminRouter.onGenerateRoute,
    );
  }
}
