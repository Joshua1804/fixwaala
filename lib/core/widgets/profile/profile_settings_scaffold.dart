import 'package:flutter/material.dart';

import '../../../features/auth/services/auth_service.dart';
import '../../models/user_model.dart';
import '../../routes/route_names.dart';
import '../../services/session_teardown.dart';
import '../../theme/app_colors.dart';
import '../async_state_builder.dart';
import 'profile_tab.dart';
import 'settings_tab.dart';

/// The Profile/Settings screen shared by both roles.
///
/// Owns the two pieces that must not live in a builder:
///
/// * **The user subscription.** Driven by [AuthService.currentUserStream]
///   rather than a `FutureBuilder` constructed inside `build()`, which fired a
///   fresh Firestore read on every rebuild.
/// * **Controller seeding.** Seeded once per identity, tracked by
///   [_seededUserId]. The previous code assigned `controller.text` inside the
///   builder, so every rebuild wiped whatever had been typed.
class ProfileSettingsScaffold extends StatefulWidget {
  /// Shown when the account has no name yet.
  final String fallbackName;

  /// Explains what notifications this role receives.
  final String notificationsSubtitle;

  /// Role-specific rows on the profile tab.
  final List<Widget> Function(BuildContext context, AppUser? user) tilesBuilder;

  /// Optional status chip under the email.
  final Widget? Function(AppUser? user)? badgeBuilder;

  /// Extra teardown to run before the session ends — cancelling per-role
  /// subscriptions, for example.
  final Future<void> Function()? onBeforeSignOut;

  const ProfileSettingsScaffold({
    super.key,
    required this.fallbackName,
    required this.notificationsSubtitle,
    required this.tilesBuilder,
    this.badgeBuilder,
    this.onBeforeSignOut,
  });

  @override
  State<ProfileSettingsScaffold> createState() =>
      _ProfileSettingsScaffoldState();
}

class _ProfileSettingsScaffoldState extends State<ProfileSettingsScaffold>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  /// Which account the controllers currently hold values for. Re-seeding only
  /// when this changes is what keeps in-progress edits from being clobbered.
  String? _seededUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _seedControllers(AppUser? user) {
    if (user == null || user.id == _seededUserId) return;
    _seededUserId = user.id;
    _nameController.text = user.name ?? '';
    _phoneController.text = user.phone ?? '';
  }

  /// Ends the session completely.
  ///
  /// Navigating away is not signing out. Every session-scoped Firestore
  /// listener has to be cancelled and its cache cleared first, otherwise the
  /// previous account's jobs, payments, and ratings stay resident in memory
  /// and the next user to sign in on this device inherits them.
  Future<void> _handleSignOut() async {
    await widget.onBeforeSignOut?.call();
    await SessionTeardown.run();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(RouteNames.roleSelection, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Settings'),
          ],
        ),
      ),
      body: AsyncStateBuilder.stream<AppUser?>(
        stream: AuthService.instance.currentUserStream,
        data: (context, user) {
          _seedControllers(user);
          return TabBarView(
            controller: _tabController,
            children: [
              ProfileTab(
                user: user,
                nameController: _nameController,
                phoneController: _phoneController,
                fallbackName: widget.fallbackName,
                badge: widget.badgeBuilder?.call(user),
                tiles: widget.tilesBuilder(context, user),
                onSave: (name, phone) async {
                  await AuthService.instance.updateProfile(
                    name: name,
                    phone: phone,
                  );
                },
              ),
              SettingsTab(
                notificationsSubtitle: widget.notificationsSubtitle,
                onSignOut: _handleSignOut,
              ),
            ],
          );
        },
      ),
    );
  }
}
