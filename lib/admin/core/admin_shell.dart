import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_text_styles.dart';
import 'admin_auth_service.dart';
import 'admin_route_names.dart';

class _NavItem {
  final String route;
  final IconData icon;
  final String label;
  const _NavItem(this.route, this.icon, this.label);
}

class _NavSection {
  final String title;
  final List<_NavItem> items;
  const _NavSection(this.title, this.items);
}

const _sections = [
  _NavSection('Overview', [
    _NavItem(AdminRouteNames.dashboard, Icons.dashboard_outlined, 'Dashboard'),
  ]),
  _NavSection('Platform', [
    _NavItem(AdminRouteNames.users, Icons.people_outline_rounded, 'Users'),
    _NavItem(
      AdminRouteNames.admins,
      Icons.admin_panel_settings_outlined,
      'Admins',
    ),
  ]),
  _NavSection('Marketplace', [
    _NavItem(
      AdminRouteNames.tickets,
      Icons.confirmation_number_outlined,
      'Tickets',
    ),
    _NavItem(AdminRouteNames.jobs, Icons.work_outline_rounded, 'Jobs'),
    _NavItem(AdminRouteNames.payments, Icons.payments_outlined, 'Payments'),
  ]),
  _NavSection('Trust & safety', [
    _NavItem(AdminRouteNames.reports, Icons.flag_outlined, 'Reports'),
    _NavItem(
      AdminRouteNames.safetyAlerts,
      Icons.emergency_outlined,
      'Safety alerts',
    ),
    _NavItem(
      AdminRouteNames.ratingsModeration,
      Icons.star_outline_rounded,
      'Ratings',
    ),
  ]),
  _NavSection('Content', [
    _NavItem(
      AdminRouteNames.announcements,
      Icons.campaign_outlined,
      'Announcements',
    ),
    _NavItem(
      AdminRouteNames.platformSettings,
      Icons.settings_outlined,
      'Settings',
    ),
  ]),
  _NavSection('System', [
    _NavItem(AdminRouteNames.media, Icons.photo_library_outlined, 'Media'),
    _NavItem(AdminRouteNames.auditLog, Icons.history_rounded, 'Audit log'),
    _NavItem(
      AdminRouteNames.monitoring,
      Icons.monitor_heart_outlined,
      'Monitoring',
    ),
  ]),
];

/// Persistent side-nav + top bar wrapping every signed-in admin screen.
///
/// Each screen renders `AdminShell(currentRoute: AdminRouteNames.x, child:
/// ...)` around its own [AdminPageScaffold] content — the same
/// each-screen-owns-its-chrome pattern the mobile app uses for its bottom
/// nav, rather than an `IndexedStack` that would keep every module's state
/// alive at once.
class AdminShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  void _go(BuildContext context, String route) {
    if (route == currentRoute) return;
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _signOut(BuildContext context) async {
    await AdminAuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AdminRouteNames.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final email = AdminAuthService.instance.currentEmail ?? '';
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 240,
            color: Theme.of(context).cardTheme.color,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 16),
                    child: Row(
                      children: [
                        Icon(Icons.handyman_rounded, color: AppColors.primary),
                        SizedBox(width: 10),
                        Text('Fixwaala Admin', style: AppTextStyles.titleLarge),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      children: [
                        for (final section in _sections) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 16, 12, 6),
                            child: Text(
                              section.title.toUpperCase(),
                              style: AppTextStyles.overline.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ),
                          for (final item in section.items)
                            _NavTile(
                              item: item,
                              selected: item.route == currentRoute,
                              onTap: () => _go(context, item.route),
                            ),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.15,
                          ),
                          child: Text(
                            email.isNotEmpty ? email[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            email,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Sign out',
                          icon: const Icon(Icons.logout_rounded, size: 18),
                          onPressed: () => _signOut(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  const _NavTile({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? AppColors.primary.withValues(alpha: 0.1) : null,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  size: 20,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Text(
                  item.label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
