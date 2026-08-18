import 'package:flutter/material.dart';

import '../../constants/app_constants.dart';
import '../../routes/route_names.dart';
import '../../services/app_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import 'profile_tile.dart';
import 'settings_section.dart';
import 'theme_option_selector.dart';

/// The "Settings" half of the profile screen — theme, notifications, account,
/// legal, and sign out.
///
/// Replaces `_SettingsContent` and `_ProviderSettingsContent`, which differed
/// only in the notification subtitle.
class SettingsTab extends StatelessWidget {
  /// Explains what notifications this role receives.
  final String notificationsSubtitle;

  /// Ends the session. Kept as a callback so each shell can also tear down
  /// its own subscriptions before navigating away.
  final Future<void> Function() onSignOut;

  /// Providers only — shows the "Set your location" row.
  final bool showLocationSetting;

  const SettingsTab({
    super.key,
    required this.notificationsSubtitle,
    required this.onSignOut,
    this.showLocationSetting = false,
  });

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
          'You will need to sign in again to book or accept jobs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );

    if (confirmed == true) await onSignOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
      children: [
        Text('App Preferences', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        const SettingsSection(child: ThemeOptionSelector()),
        const SizedBox(height: 24),
        Text('Notifications', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        SettingsSection(
          child: StreamBuilder<bool>(
            stream: AppPreferencesService.instance.notificationsEnabledStream,
            initialData: AppPreferencesService.instance.notificationsEnabled,
            builder: (context, snapshot) {
              final enabled = snapshot.data ?? true;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enable notifications',
                          style: AppTextStyles.bodyLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notificationsSubtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: enabled,
                    onChanged:
                        AppPreferencesService.instance.setNotificationsEnabled,
                    activeThumbColor: AppColors.primary,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 24),
        Text('Account', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        // TODO(phase-8): re-auth + updatePassword flow.
        const ProfileTile(
          icon: Icons.lock_outline_rounded,
          label: 'Change Password',
          onTap: null,
        ),
        if (showLocationSetting) ...[
          const SizedBox(height: 12),
          ProfileTile(
            icon: Icons.map_outlined,
            label: 'Set your location',
            onTap: () =>
                Navigator.of(context).pushNamed(RouteNames.providerLocation),
          ),
        ],
        const SizedBox(height: 24),
        Text('About', style: AppTextStyles.titleLarge),
        const SizedBox(height: 16),
        ProfileTile(
          icon: Icons.privacy_tip_outlined,
          label: 'Privacy Policy',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.privacyPolicy),
        ),
        ProfileTile(
          icon: Icons.description_outlined,
          label: 'Terms of Service',
          onTap: () =>
              Navigator.of(context).pushNamed(RouteNames.termsOfService),
        ),
        ProfileTile(
          icon: Icons.info_outline_rounded,
          label: 'Version Info',
          onTap: () => showAboutDialog(
            context: context,
            applicationName: AppConstants.appName,
            applicationVersion: '1.0.0 (build 1)',
          ),
        ),
        const SizedBox(height: 24),
        ProfileTile(
          icon: Icons.logout_rounded,
          label: 'Sign Out',
          isDestructive: true,
          onTap: () => _confirmSignOut(context),
        ),
      ],
    );
  }
}
