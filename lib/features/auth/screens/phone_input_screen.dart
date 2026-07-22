import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// Phone number input with role-specific header icon and premium styling.
class PhoneInputScreen extends StatefulWidget {
  const PhoneInputScreen({super.key});

  @override
  State<PhoneInputScreen> createState() => _PhoneInputScreenState();
}

class _PhoneInputScreenState extends State<PhoneInputScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _sending = false;

  late final AnimationController _entranceController;
  late final Animation<double> _headerFade;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _formFade;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _formSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    ));
    _formFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit(UserRole role) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      final verificationId =
          await AuthService.instance.sendOtp(_controller.text.trim());
      if (!mounted) return;
      setState(() => _sending = false);
      Navigator.of(context).pushNamed(
        RouteNames.otpVerification,
        arguments: {
          'role': role,
          'phone': _controller.text.trim(),
          'verificationId': verificationId,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send OTP: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ModalRoute.of(context)?.settings.arguments as UserRole? ??
        UserRole.customer;
    final isCustomer = role == UserRole.customer;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Sign in'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                // ── Header icon + text ─────────────────────────
                FadeTransition(
                  opacity: _headerFade,
                  child: Column(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isCustomer
                                ? [AppColors.primary, AppColors.primaryLight]
                                : [AppColors.accent, AppColors.accentLight],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isCustomer
                                      ? AppColors.primary
                                      : AppColors.accent)
                                  .withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Icon(
                          isCustomer
                              ? Icons.home_repair_service_rounded
                              : Icons.build_circle_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        AppStrings.enterPhone,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll send you a 6-digit verification code',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Phone input ────────────────────────────────
                SlideTransition(
                  position: _formSlide,
                  child: FadeTransition(
                    opacity: _formFade,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _controller,
                          keyboardType: TextInputType.phone,
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          decoration: InputDecoration(
                            counterText: '',
                            prefixIcon: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 14),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '🇮🇳',
                                    style: AppTextStyles.bodyLarge,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '+91',
                                    style: AppTextStyles.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: AppColors.divider,
                                  ),
                                ],
                              ),
                            ),
                            hintText: '98765 43210',
                            hintStyle: AppTextStyles.bodyLarge.copyWith(
                              color: AppColors.textHint,
                              letterSpacing: 1.2,
                            ),
                          ),
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          label: 'Send OTP',
                          icon: Icons.sms_outlined,
                          loading: _sending,
                          useGradient: true,
                          onPressed: () => _submit(role),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(),

                // ── Privacy note ───────────────────────────────
                FadeTransition(
                  opacity: _formFade,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 14,
                          color: AppColors.textHint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Your number is safe with us',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
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
