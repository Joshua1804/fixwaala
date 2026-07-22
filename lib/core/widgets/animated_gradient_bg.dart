import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A slowly animating gradient background used on splash and auth screens.
///
/// Creates a subtle, alive-feeling backdrop by shifting the gradient alignment.
class AnimatedGradientBg extends StatefulWidget {
  final List<Color>? colors;
  final Widget child;
  final Duration duration;

  const AnimatedGradientBg({
    super.key,
    required this.child,
    this.colors,
    this.duration = const Duration(seconds: 4),
  });

  @override
  State<AnimatedGradientBg> createState() => _AnimatedGradientBgState();
}

class _AnimatedGradientBgState extends State<AnimatedGradientBg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = widget.colors ??
        (isDark
            ? const [Color(0xFF0A1628), Color(0xFF0F2E22), Color(0xFF0A1628)]
            : const [
                AppColors.primaryDark,
                AppColors.primary,
                AppColors.primaryLight,
              ]);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-(1.0 - t), -1),
              end: Alignment(1.0 - t, 1),
              colors: colors,
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
