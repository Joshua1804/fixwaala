import 'package:flutter/material.dart';

import '../features/dashboard/admin_dashboard_screen.dart';
import '../features/auth/admin_login_screen.dart';
import 'admin_auth_service.dart';
import 'admin_route_names.dart';
import 'admin_shell.dart';

/// Root of the admin app's widget tree (`MaterialApp.home`). Listens to the
/// live auth+claim stream and shows the login screen or the dashboard —
/// nothing else in the app has to think about whether anyone is signed in,
/// because nothing else is reachable until this widget decides they are.
class AdminAuthGate extends StatelessWidget {
  const AdminAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AdminAuthState>(
      stream: AdminAuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null || state.status == AdminAuthStatus.checking) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == AdminAuthStatus.forbidden) {
          return AdminLoginScreen(deniedEmail: state.email);
        }
        if (state.status == AdminAuthStatus.signedOut) {
          return const AdminLoginScreen();
        }
        return const AdminShell(
          currentRoute: AdminRouteNames.dashboard,
          child: AdminDashboardScreen(),
        );
      },
    );
  }
}
