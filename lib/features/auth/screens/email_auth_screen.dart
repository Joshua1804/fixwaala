import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// Human-readable label for a role, matching how it's used in copy
/// elsewhere in the auth flow ("Create your provider account", etc.).
String _roleLabel(UserRole role) =>
    role == UserRole.provider ? 'Provider' : 'Customer';

/// Null when [accountRole] matches the role of the login page the user is
/// on ([loginPageRole]); otherwise a message explaining the mismatch, for
/// the "wrong login page" dialog shown after a successful sign-in.
String? roleMismatchMessage({
  required UserRole loginPageRole,
  required UserRole accountRole,
}) {
  if (loginPageRole == accountRole) return null;
  return 'This is a ${_roleLabel(accountRole)} account, but you signed in '
      'on the ${_roleLabel(loginPageRole)} page.';
}

/// Email/password sign-in and registration (Module 1).
///
/// The role argument only matters for registration — an existing user's
/// role is always looked up from their saved Firestore profile, never from
/// whatever was tapped on the role-selection screen. That distinction is
/// what fixes customers and providers being routed to the same page.
class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegister = true;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(UserRole role) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isRegister) {
        await AuthService.instance.register(
          name: _nameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          role: role,
        );
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushReplacementNamed(RouteNames.emailVerification);
      } else {
        final user = await AuthService.instance.login(
          email: _emailController.text,
          password: _passwordController.text,
        );
        if (!mounted) return;
        final mismatch = roleMismatchMessage(
          loginPageRole: role,
          accountRole: user.role,
        );
        if (mismatch != null) {
          final goToCorrectPage = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Wrong sign-in page'),
              content: Text(
                '$mismatch Go to the ${_roleLabel(user.role)} sign-in page instead?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Continue anyway'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Take me there'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (goToCorrectPage == true) {
            Navigator.of(context).pushReplacementNamed(
              RouteNames.emailAuth,
              arguments: user.role,
            );
            return;
          }
        }
        final destination = await AuthService.instance.resolveInitialRoute();
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(destination, (route) => false);
      }
    } catch (e) {
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitGoogle(UserRole role) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await AuthService.instance.signInWithGoogle(role: role);
      if (!mounted) return;
      final mismatch = roleMismatchMessage(
        loginPageRole: role,
        accountRole: user.role,
      );
      if (mismatch != null) {
        final goToCorrectPage = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Wrong sign-in page'),
            content: Text(
              '$mismatch Go to the ${_roleLabel(user.role)} sign-in page instead?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Continue anyway'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Take me there'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (goToCorrectPage == true) {
          Navigator.of(context).pushReplacementNamed(
            RouteNames.emailAuth,
            arguments: user.role,
          );
          return;
        }
      }
      final destination = await AuthService.instance.resolveInitialRoute();
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(destination, (route) => false);
    } catch (e) {
      if (e is AuthException && e.code == 'canceled') {
        // Silently clear loading on user cancellation
        return;
      }
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role =
        ModalRoute.of(context)?.settings.arguments as UserRole? ??
        UserRole.customer;
    final isCustomer = role == UserRole.customer;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isRegister ? 'Create account' : 'Sign in'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isCustomer
                            ? [AppColors.primary, AppColors.primaryLight]
                            : [AppColors.accent, AppColors.accentLight],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isCustomer
                          ? Icons.home_repair_service_rounded
                          : Icons.build_circle_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isRegister
                      ? (isCustomer
                            ? 'Create your customer account'
                            : 'Create your provider account')
                      : 'Welcome back',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegister
                      ? 'We\'ll send a verification link to your email.'
                      : 'Sign in with your email and password.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                if (_isRegister) ...[
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline_rounded),
                    ),
                    validator: (v) => Validators.required(v, field: 'Name'),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Email is required';
                    }
                    return Validators.email(v);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (_isRegister) return Validators.newPassword(v);
                    return null;
                  },
                ),
                if (!_isRegister) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(
                        context,
                      ).pushNamed(RouteNames.passwordReset),
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _isRegister ? 'Create account' : 'Sign in',
                  loading: _submitting,
                  useGradient: true,
                  onPressed: _submitting ? null : () => _submit(role),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'OR',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: _submitting ? null : () => _submitGoogle(role),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.divider),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.g_mobiledata_rounded, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Sign in with Google',
                        style: AppTextStyles.buttonText.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _submitting
                        ? null
                        : () => setState(() {
                            _isRegister = !_isRegister;
                            _error = null;
                          }),
                    child: Text(
                      _isRegister
                          ? 'Already have an account? Sign in'
                          : 'New here? Create an account',
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
