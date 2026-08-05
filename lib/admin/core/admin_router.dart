import 'package:flutter/material.dart';

import '../features/admins/admin_admins_screen.dart';
import '../features/audit/admin_audit_log_screen.dart';
import '../features/auth/admin_login_screen.dart';
import '../features/content/admin_announcements_screen.dart';
import '../features/dashboard/admin_dashboard_screen.dart';
import '../features/media/admin_media_screen.dart';
import '../features/moderation/admin_ratings_screen.dart';
import '../features/monitoring/admin_monitoring_screen.dart';
import '../features/moderation/admin_report_detail_screen.dart';
import '../features/moderation/admin_report_list_screen.dart';
import '../features/moderation/admin_safety_alerts_screen.dart';
import '../features/payments/admin_payment_detail_screen.dart';
import '../features/payments/admin_payment_list_screen.dart';
import '../features/settings/admin_platform_settings_screen.dart';
import '../features/tickets_jobs/admin_job_detail_screen.dart';
import '../features/tickets_jobs/admin_job_list_screen.dart';
import '../features/tickets_jobs/admin_ticket_detail_screen.dart';
import '../features/tickets_jobs/admin_ticket_list_screen.dart';
import '../features/users/admin_user_detail_screen.dart';
import '../features/users/admin_user_list_screen.dart';
import 'admin_route_names.dart';
import 'admin_shell.dart';

/// Route table for every screen reachable *after* [AdminAuthGate] has
/// already decided the visitor is signed in — mirrors the mobile app's
/// `AppRouter` in shape (a switch over [RouteSettings.name], each case
/// wrapping its screen in a [MaterialPageRoute]).
///
/// Every case except `login` wraps its screen in [AdminShell] so the side
/// nav and top bar stay put across navigation — each screen owns its own
/// chrome rather than the app owning one persistent scaffold, matching how
/// the mobile app's per-route bottom nav works.
class AdminRouter {
  AdminRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AdminRouteNames.login:
        return _page(const AdminLoginScreen(), settings);

      case AdminRouteNames.dashboard:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.dashboard,
            child: AdminDashboardScreen(),
          ),
          settings,
        );

      case AdminRouteNames.users:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.users,
            child: AdminUserListScreen(),
          ),
          settings,
        );
      case AdminRouteNames.userDetail:
        return _page(
          AdminShell(
            currentRoute: AdminRouteNames.users,
            child: AdminUserDetailScreen(
              userId: settings.arguments as String? ?? '',
            ),
          ),
          settings,
        );

      case AdminRouteNames.admins:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.admins,
            child: AdminAdminsScreen(),
          ),
          settings,
        );

      case AdminRouteNames.tickets:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.tickets,
            child: AdminTicketListScreen(),
          ),
          settings,
        );
      case AdminRouteNames.ticketDetail:
        return _page(
          AdminShell(
            currentRoute: AdminRouteNames.tickets,
            child: AdminTicketDetailScreen(
              ticketId: settings.arguments as String? ?? '',
            ),
          ),
          settings,
        );
      case AdminRouteNames.jobs:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.jobs,
            child: AdminJobListScreen(),
          ),
          settings,
        );
      case AdminRouteNames.jobDetail:
        return _page(
          AdminShell(
            currentRoute: AdminRouteNames.jobs,
            child: AdminJobDetailScreen(
              jobId: settings.arguments as String? ?? '',
            ),
          ),
          settings,
        );

      case AdminRouteNames.payments:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.payments,
            child: AdminPaymentListScreen(),
          ),
          settings,
        );
      case AdminRouteNames.paymentDetail:
        return _page(
          AdminShell(
            currentRoute: AdminRouteNames.payments,
            child: AdminPaymentDetailScreen(
              paymentId: settings.arguments as String? ?? '',
            ),
          ),
          settings,
        );

      case AdminRouteNames.reports:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.reports,
            child: AdminReportListScreen(),
          ),
          settings,
        );
      case AdminRouteNames.reportDetail:
        return _page(
          AdminShell(
            currentRoute: AdminRouteNames.reports,
            child: AdminReportDetailScreen(
              reportId: settings.arguments as String? ?? '',
            ),
          ),
          settings,
        );
      case AdminRouteNames.safetyAlerts:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.safetyAlerts,
            child: AdminSafetyAlertsScreen(),
          ),
          settings,
        );
      case AdminRouteNames.ratingsModeration:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.ratingsModeration,
            child: AdminRatingsScreen(),
          ),
          settings,
        );

      case AdminRouteNames.announcements:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.announcements,
            child: AdminAnnouncementsScreen(),
          ),
          settings,
        );
      case AdminRouteNames.platformSettings:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.platformSettings,
            child: AdminPlatformSettingsScreen(),
          ),
          settings,
        );

      case AdminRouteNames.media:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.media,
            child: AdminMediaScreen(),
          ),
          settings,
        );
      case AdminRouteNames.auditLog:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.auditLog,
            child: AdminAuditLogScreen(),
          ),
          settings,
        );
      case AdminRouteNames.monitoring:
        return _page(
          const AdminShell(
            currentRoute: AdminRouteNames.monitoring,
            child: AdminMonitoringScreen(),
          ),
          settings,
        );

      default:
        return _page(
          Scaffold(
            body: Center(child: Text('Unknown route: ${settings.name}')),
          ),
          settings,
        );
    }
  }

  static MaterialPageRoute _page(Widget child, RouteSettings settings) {
    return MaterialPageRoute(builder: (_) => child, settings: settings);
  }
}
