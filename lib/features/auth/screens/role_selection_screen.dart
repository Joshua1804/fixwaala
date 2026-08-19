import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/glassmorphic_card.dart';

/// Premium role selection screen with gradient background and
/// glassmorphic role cards with staggered entrance animations.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _gradientController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _headerSlide;
  late final Animation<double> _card1Fade;
  late final Animation<Offset> _card1Slide;
  late final Animation<double> _card2Fade;
  late final Animation<Offset> _card2Slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    // Header: 0–40%
    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _headerSlide = Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
          ),
        );

    // Card 1: 15–55%
    _card1Fade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );
    _card1Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.15, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    // Card 2: 30–70%
    _card2Fade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );
    _card2Slide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.3, 0.7, curve: Curves.easeOutCubic),
          ),
        );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _gradientController.dispose();
    super.dispose();
  }

  void _pick(UserRole role) {
    Navigator.of(context).pushNamed(RouteNames.emailAuth, arguments: role);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: _gradientController,
          builder: (context, child) {
            final t = _gradientController.value;
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-(0.5 - t * 0.5), -1),
                  end: Alignment(0.5 + t * 0.5, 1),
                  colors: const [
                    AppColors.scaffoldDark,
                    AppColors.primaryDark,
                    AppColors.primary,
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 48),

                  // ── Header ──────────────────────────────────────
                  SlideTransition(
                    position: _headerSlide,
                    child: FadeTransition(
                      opacity: _headerFade,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Image.asset(
                              'assets/icon/app_icon_foreground.png',
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Welcome to\nFixwaala',
                            style: AppTextStyles.displayMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            AppStrings.selectRolePrompt,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // ── Role Card: Customer ────────────────────────
                  SlideTransition(
                    position: _card1Slide,
                    child: FadeTransition(
                      opacity: _card1Fade,
                      child: _PremiumRoleCard(
                        icon: Icons.home_repair_service_rounded,
                        title: AppStrings.roleCustomer,
                        subtitle:
                            'Book rated plumbers, electricians\n& carpenters near you.',
                        accentColor: AppColors.accentLight,
                        onTap: () => _pick(UserRole.customer),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // ── Role Card: Provider ────────────────────────
                  SlideTransition(
                    position: _card2Slide,
                    child: FadeTransition(
                      opacity: _card2Fade,
                      child: _PremiumRoleCard(
                        icon: Icons.build_circle_rounded,
                        title: AppStrings.roleProvider,
                        subtitle: 'Accept nearby jobs and\ngrow your business.',
                        accentColor: AppColors.primaryLight,
                        onTap: () => _pick(UserRole.provider),
                      ),
                    ),
                  ),

                  const Spacer(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Premium Role Card ───────────────────────────────────────────────
class _PremiumRoleCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  const _PremiumRoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_PremiumRoleCard> createState() => _PremiumRoleCardState();
}

class _PremiumRoleCardState extends State<_PremiumRoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hoverController;
  late final Animation<double> _hoverScale;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _hoverScale = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _hoverController.forward(),
      onTapUp: (_) {
        _hoverController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _hoverController.reverse(),
      child: ScaleTransition(
        scale: _hoverScale,
        child: GlassmorphicCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.accentColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.titleLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
