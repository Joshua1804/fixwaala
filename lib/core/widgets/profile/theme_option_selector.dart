import 'package:flutter/material.dart';

import '../../services/app_preferences_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';

/// Light / Dark / System picker wired straight to [AppPreferencesService].
///
/// Previously a private `_buildThemeOption` method duplicated in both home
/// screens — including the hardcoded [AppColors.textPrimary] on the unselected
/// label, which is near-invisible against the dark scaffold. Unselected labels
/// now read from the theme so they stay legible in both modes.
class ThemeOptionSelector extends StatelessWidget {
  const ThemeOptionSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ThemeMode>(
      stream: AppPreferencesService.instance.themeModeStream,
      initialData: AppPreferencesService.instance.themeMode,
      builder: (context, snapshot) {
        final current = snapshot.data ?? ThemeMode.system;
        return Column(
          children: [
            _ThemeOption(
              label: 'Light',
              mode: ThemeMode.light,
              icon: Icons.light_mode_rounded,
              isSelected: current == ThemeMode.light,
            ),
            const SizedBox(height: 12),
            _ThemeOption(
              label: 'Dark',
              mode: ThemeMode.dark,
              icon: Icons.dark_mode_rounded,
              isSelected: current == ThemeMode.dark,
            ),
            const SizedBox(height: 12),
            _ThemeOption(
              label: 'System',
              mode: ThemeMode.system,
              icon: Icons.brightness_auto_rounded,
              isSelected: current == ThemeMode.system,
            ),
          ],
        );
      },
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final ThemeMode mode;
  final IconData icon;
  final bool isSelected;

  const _ThemeOption({
    required this.label,
    required this.mode,
    required this.icon,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unselectedText =
        theme.textTheme.bodyLarge?.color ?? AppColors.textSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label theme',
      child: GestureDetector(
        onTap: () => AppPreferencesService.instance.setThemeMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.divider,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: isSelected ? AppColors.primary : unselectedText,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(Icons.check_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
