import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// Blocks access to the app until the user's email is verified.
///
/// Offers "Resend email" (with a cooldown) and "I've verified — Continue",
/// which reloads the Firebase user and re-checks. In simulation mode (no
/// Firebase project configured) a demo-only "Simulate verification" action
/// is shown instead, since no real email can be sent.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _checking = false;
  bool _resending = false;
  String? _error;
  String? _info;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUser() async {
    final user = await AuthService.instance.currentUser();
    if (!mounted) return;
    setState(() => _user = user);
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 30);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCooldown--;
        if (_resendCooldown <= 0) timer.cancel();
      });
    });
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });
    try {
      await AuthService.instance.sendEmailVerification();
      if (!mounted) return;
      setState(() => _info = 'Verification email sent.');
      _startCooldown();
    } catch (e) {
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _continue() async {
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final verified = await AuthService.instance.reloadAndCheckEmailVerified();
      if (!verified) {
        setState(
          () => _error =
              'Your email is not verified yet. Please check your inbox.',
        );
        return;
      }
      if (!mounted) return;
      final destination = await AuthService.instance.resolveInitialRoute();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    } catch (e) {
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _simulateVerified() async {
    AuthService.instance.simulateVerifyEmail();
    final destination = await AuthService.instance.resolveInitialRoute();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(destination, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final isLive = FirebaseService.instance.isInitialized;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify your email'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil(RouteNames.roleSelection, (r) => false);
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 72,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Check your inbox',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _user?.email == null
                  ? 'We sent you a verification link.'
                  : 'We sent a verification link to ${_user!.email}.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You cannot access Fixwaala until your email is verified.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textHint, fontSize: 13),
            ),
            if (_info != null) ...[
              const SizedBox(height: 16),
              Text(_info!, style: const TextStyle(color: AppColors.success)),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: AppColors.error)),
            ],
            const SizedBox(height: 32),
            PrimaryButton(
              label: 'I\'ve verified — Continue',
              loading: _checking,
              useGradient: true,
              onPressed: _checking ? null : _continue,
            ),
            const SizedBox(height: 12),
            if (isLive)
              OutlinedButton(
                onPressed: (_resending || _resendCooldown > 0) ? null : _resend,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend email (${_resendCooldown}s)'
                      : 'Resend verification email',
                ),
              )
            else
              OutlinedButton(
                onPressed: _simulateVerified,
                child: const Text('Simulate: mark my email as verified (demo)'),
              ),
          ],
        ),
      ),
    );
  }
}
