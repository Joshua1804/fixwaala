import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/services/auth_service.dart';
import '../constants/app_constants.dart';
import '../constants/app_strings.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/motion.dart';

/// Animated splash screen with gradient background, fade-in logo,
/// and smooth transition to role selection.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _gradientController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleUp;
  late final Animation<double> _taglineFade;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();

    // Main fade / scale entrance
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _scaleUp = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    // Pulsing loader
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Gradient shift
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    if (prefersReducedMotion) {
      _pulseController.value = 1.0;
      _gradientController.value = 0.5;
      _fadeController.value = 1.0;
    } else {
      _pulseController.repeat(reverse: true);
      _gradientController.repeat(reverse: true);
      _fadeController.forward();
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final results = await Future.wait([
      AuthService.instance.resolveInitialRoute(),
      Future.delayed(const Duration(seconds: 2)),
    ]);
    if (!mounted) return;
    final destination = results[0] as String;
    Navigator.of(context).pushReplacementNamed(destination);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _gradientController.dispose();
    super.dispose();
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
                  begin: Alignment(-(1.0 - t), -1),
                  end: Alignment(1.0 - t, 1),
                  colors: const [
                    Color(0xFF07130D),
                    AppColors.primaryDark,
                    AppColors.primary,
                    AppColors.primaryHover,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Spacer(flex: 3),

                  // ── Logo icon ─────────────────────────────────
                  FadeTransition(
                    opacity: _fadeIn,
                    child: ScaleTransition(
                      scale: _scaleUp,
                      child: Container(
                        width: 100,
                        height: 100,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                        child: Image.asset(
                          'assets/icon/app_icon_foreground.png',
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── App name ──────────────────────────────────
                  FadeTransition(
                    opacity: _fadeIn,
                    child: Text(
                      AppConstants.appName,
                      style: AppTextStyles.displayMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Tagline ───────────────────────────────────
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      AppStrings.tagline,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Pulsing loader ────────────────────────────
                  FadeTransition(
                    opacity: _pulse,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
