import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_durations.dart';
import '../theme/app_radii.dart';
import '../theme/app_text_styles.dart';
import '../utils/motion.dart';
import 'service_category_ui.dart';

/// A tappable service-category tile with a sage circular icon container,
/// press feedback, and a selected-state color swap.
class ServiceCategoryTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const ServiceCategoryTile({
    super.key,
    required this.label,
    required this.icon,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<ServiceCategoryTile> createState() => _ServiceCategoryTileState();
}

class _ServiceCategoryTileState extends State<ServiceCategoryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppDurations.pressScale,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _press(bool down) {
    if (prefersReducedMotion) return;
    if (down) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconBg = ServiceCategoryUi.iconBg(selected: widget.selected);
    final iconFg = ServiceCategoryUi.iconFg(selected: widget.selected);

    return GestureDetector(
      onTapDown: (_) => _press(true),
      onTapUp: (_) {
        _press(false);
        widget.onTap();
      },
      onTapCancel: () => _press(false),
      child: ScaleTransition(
        scale: _scale,
        child: Semantics(
          button: true,
          label: widget.label,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius: BorderRadius.circular(AppRadii.categoryIcon),
              border: Border.all(
                color: AppColors.divider.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: AppDurations.selection,
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconBg,
                    shape: BoxShape.circle,
                    border: Border.all(color: ServiceCategoryUi.iconBorder()),
                  ),
                  child: Icon(widget.icon, color: iconFg, size: 26),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
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
