/// Route names for the admin website. A separate namespace from the mobile
/// app's [RouteNames] — the two never navigate to each other and are never
/// compiled into the same binary.
class AdminRouteNames {
  AdminRouteNames._();

  static const login = '/login';
  static const dashboard = '/dashboard';

  static const users = '/users';
  static const userDetail = '/users/detail';

  static const admins = '/admins';

  static const tickets = '/tickets';
  static const ticketDetail = '/tickets/detail';
  static const jobs = '/jobs';
  static const jobDetail = '/jobs/detail';

  static const payments = '/payments';
  static const paymentDetail = '/payments/detail';

  static const reports = '/reports';
  static const reportDetail = '/reports/detail';
  static const safetyAlerts = '/safety-alerts';
  static const ratingsModeration = '/ratings';

  static const announcements = '/announcements';
  static const platformSettings = '/settings';

  static const media = '/media';
  static const auditLog = '/audit-log';
  static const monitoring = '/monitoring';
}
