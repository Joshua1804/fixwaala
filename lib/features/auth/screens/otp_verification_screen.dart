import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// OTP verification with individual digit boxes, auto-focus advancement,
/// countdown timer for resend, and success animation.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with TickerProviderStateMixin {
  static const _otpLength = AppConstants.otpLength;

  final List<TextEditingController> _controllers = List.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(
    _otpLength,
    (_) => FocusNode(),
  );

  bool _verifying = false;
  int _resendCountdown = AppConstants.otpResendSeconds;
  Timer? _resendTimer;

  late final AnimationController _entranceController;
  late final Animation<double> _headerFade;
  late final Animation<double> _boxesFade;
  late final Animation<Offset> _boxesSlide;

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
    _boxesFade = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    );
    _boxesSlide = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 0.8, curve: Curves.easeOut),
    ));
    _entranceController.forward();

    _startResendTimer();
  }

  void _startResendTimer() {
    _resendCountdown = AppConstants.otpResendSeconds;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) _resendTimer?.cancel();
    });
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  bool get _isOtpComplete =>
      _controllers.every((c) => c.text.length == 1) &&
      _otpCode.length == _otpLength;

  void _onDigitChanged(int index, String value) {
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    // Auto-verify when all digits entered
    if (_isOtpComplete) {
      _verify();
    }
    setState(() {});
  }

  void _onKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_isOtpComplete || _verifying) return;
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            const {};
    setState(() => _verifying = true);
    try {
      final user = await AuthService.instance.verifyOtp(
        verificationId: args['verificationId'] as String,
        smsCode: _otpCode,
        role: args['role'] as UserRole,
      );
      final onboarded =
          await AuthService.instance.isOnboarded(user.id, user.role);
      if (!mounted) return;
      if (!onboarded) {
        Navigator.of(context)
            .pushReplacementNamed(RouteNames.registration, arguments: user);
      } else {
        Navigator.of(context).pushReplacementNamed(
          user.role == UserRole.provider
              ? RouteNames.providerHome
              : RouteNames.customerHome,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Verification failed: $e')));
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend(Map<String, dynamic> args) async {
    if (_resendCountdown > 0) return;
    await AuthService.instance.sendOtp(args['phone'] as String? ?? '');
    _startResendTimer();
  }

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ??
            const {};
    final phone = args['phone'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Verify OTP'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),

              // ── Header ──────────────────────────────────────
              FadeTransition(
                opacity: _headerFade,
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.sms_outlined,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      AppStrings.enterOtp,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Sent to +91 $phone',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Edit',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── OTP digit boxes ─────────────────────────────
              SlideTransition(
                position: _boxesSlide,
                child: FadeTransition(
                  opacity: _boxesFade,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_otpLength, (i) {
                      final hasValue = _controllers[i].text.isNotEmpty;
                      return Container(
                        width: 48,
                        height: 56,
                        margin: EdgeInsets.only(
                          right: i < _otpLength - 1 ? 10 : 0,
                        ),
                        child: KeyboardListener(
                          focusNode: FocusNode(),
                          onKeyEvent: (e) => _onKeyDown(i, e),
                          child: TextField(
                            controller: _controllers[i],
                            focusNode: _focusNodes[i],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            style: AppTextStyles.headlineMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              filled: true,
                              fillColor: hasValue
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : null,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: hasValue
                                      ? AppColors.primary
                                      : AppColors.divider,
                                  width: hasValue ? 1.5 : 1,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 2,
                                ),
                              ),
                            ),
                            onChanged: (v) => _onDigitChanged(i, v),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Demo Instruction Banner ─────────────────────
              FadeTransition(
                opacity: _boxesFade,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Demo Mode: Enter any 6-digit code (e.g. 123456) to verify and proceed.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Verify button ───────────────────────────────
              FadeTransition(
                opacity: _boxesFade,
                child: PrimaryButton(
                  label: 'Verify',
                  loading: _verifying,
                  useGradient: true,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: _isOtpComplete ? _verify : null,
                ),
              ),

              const SizedBox(height: 24),

              // ── Resend ──────────────────────────────────────
              FadeTransition(
                opacity: _boxesFade,
                child: Center(
                  child: _resendCountdown > 0
                      ? RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Resend OTP in '),
                              TextSpan(
                                text: '${_resendCountdown}s',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : TextButton(
                          onPressed: () => _resend(args),
                          child: Text(
                            'Resend OTP',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                ),
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
