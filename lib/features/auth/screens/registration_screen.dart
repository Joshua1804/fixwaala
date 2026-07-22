import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// Registration screen with avatar placeholder, premium form fields,
/// role-specific skill selection chips (for providers), and step indicator.
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;

  // Provider skill selection
  final Set<ServiceCategory> _selectedSkills = {};

  late final AnimationController _entranceController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fade = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    ));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save(AppUser user) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (user.role == UserRole.provider && _selectedSkills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one skill')),
      );
      return;
    }
    setState(() => _saving = true);
    // Persist name/email to mock/Firebase service
    await AuthService.instance.updateProfile(
      name: _nameController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
    );
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (user.role == UserRole.provider) {
      Navigator.of(context).pushReplacementNamed(RouteNames.aadhaarEntry);
    } else {
      Navigator.of(context).pushReplacementNamed(RouteNames.customerHome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ModalRoute.of(context)?.settings.arguments as AppUser?;
    final isProvider = user?.role == UserRole.provider;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Complete profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 16),

                    // ── Step indicator ──────────────────────────
                    _StepIndicator(
                      currentStep: isProvider ? 1 : 1,
                      totalSteps: isProvider ? 3 : 2,
                      labels: isProvider
                          ? const ['Phone', 'Profile', 'Verify']
                          : const ['Phone', 'Profile'],
                    ),

                    const SizedBox(height: 32),

                    // ── Avatar placeholder ──────────────────────
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.2),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              size: 40,
                              color: AppColors.primary,
                            ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Name field ──────────────────────────────
                    Text(
                      'Full name',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        hintText: 'Enter your full name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (v) => Validators.required(v, field: 'Name'),
                    ),

                    const SizedBox(height: 20),

                    // ── Email field ──────────────────────────────
                    Text(
                      'Email (optional)',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'name@example.com',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: Validators.email,
                    ),

                    // ── Provider-only: Skill chips ──────────────
                    if (isProvider) ...[
                      const SizedBox(height: 28),
                      Text(
                        'Your skills',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select the services you offer',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _SkillChip(
                            label: 'Plumbing',
                            icon: Icons.plumbing,
                            color: AppColors.plumbing,
                            selected: _selectedSkills
                                .contains(ServiceCategory.plumber),
                            onTap: () => setState(() {
                              _selectedSkills
                                      .contains(ServiceCategory.plumber)
                                  ? _selectedSkills
                                      .remove(ServiceCategory.plumber)
                                  : _selectedSkills
                                      .add(ServiceCategory.plumber);
                            }),
                          ),
                          _SkillChip(
                            label: 'Electrical',
                            icon: Icons.electrical_services,
                            color: AppColors.electrical,
                            selected: _selectedSkills
                                .contains(ServiceCategory.electrician),
                            onTap: () => setState(() {
                              _selectedSkills
                                      .contains(ServiceCategory.electrician)
                                  ? _selectedSkills
                                      .remove(ServiceCategory.electrician)
                                  : _selectedSkills
                                      .add(ServiceCategory.electrician);
                            }),
                          ),
                          _SkillChip(
                            label: 'Carpentry',
                            icon: Icons.chair_alt,
                            color: AppColors.carpentry,
                            selected: _selectedSkills
                                .contains(ServiceCategory.carpenter),
                            onTap: () => setState(() {
                              _selectedSkills
                                      .contains(ServiceCategory.carpenter)
                                  ? _selectedSkills
                                      .remove(ServiceCategory.carpenter)
                                  : _selectedSkills
                                      .add(ServiceCategory.carpenter);
                            }),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 40),

                    // ── Continue button ─────────────────────────
                    PrimaryButton(
                      label: 'Continue',
                      icon: Icons.arrow_forward_rounded,
                      loading: _saving,
                      useGradient: true,
                      onPressed: user == null ? null : () => _save(user),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Step Indicator ──────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;

  const _StepIndicator({
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (i) {
        if (i.isOdd) {
          // Connector line
          final stepBefore = i ~/ 2;
          final isCompleted = stepBefore < currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted
                  ? AppColors.primary
                  : AppColors.divider,
            ),
          );
        }
        final stepIndex = i ~/ 2;
        final isCompleted = stepIndex < currentStep;
        final isCurrent = stepIndex == currentStep;

        return Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.primary
                    : isCurrent
                        ? AppColors.primary.withValues(alpha: 0.15)
                        : AppColors.divider.withValues(alpha: 0.5),
                border: isCurrent
                    ? Border.all(color: AppColors.primary, width: 2)
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : Text(
                        '${stepIndex + 1}',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isCurrent
                              ? AppColors.primary
                              : AppColors.textHint,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              labels[stepIndex],
              style: AppTextStyles.caption.copyWith(
                color: isCurrent || isCompleted
                    ? AppColors.primary
                    : AppColors.textHint,
                fontWeight:
                    isCurrent ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Skill Chip ──────────────────────────────────────────────────────
class _SkillChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _SkillChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : AppColors.divider,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: selected ? color : AppColors.textHint),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelLarge.copyWith(
                color: selected ? color : AppColors.textSecondary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              Icon(Icons.check_circle, size: 16, color: color),
            ],
          ],
        ),
      ),
    );
  }
}
