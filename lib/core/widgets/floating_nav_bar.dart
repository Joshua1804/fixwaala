import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_durations.dart';
import '../theme/app_shadows.dart';
import '../utils/motion.dart';

class FloatingNavBarItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;

  const FloatingNavBarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
  });
}

/// A pill-shaped bottom navigation bar that floats above the screen edge
/// with margin on all sides, replacing the edge-to-edge
/// [BottomNavigationBar] look used previously. Icon-only — labels are
/// carried on [FloatingNavBarItem] for semantics/tooltips only, since a
/// visible label on a narrow floating pill either wraps or truncates.
class FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavBarItem> items;

  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          boxShadow: AppShadows.raised,
          border: isDark ? Border.all(color: AppColors.glassBorderDark) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < items.length; i++)
              _FloatingNavItem(
                item: items[i],
                selected: i == currentIndex,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _FloatingNavItem extends StatelessWidget {
  final FloatingNavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  const _FloatingNavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textHint;

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: prefersReducedMotion
              ? Duration.zero
              : AppDurations.selection,
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            selected ? (item.activeIcon ?? item.icon) : item.icon,
            color: color,
            size: 24,
          ),
        ),
      ),
    );
  }
}
