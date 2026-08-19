import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/routes/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/auth_service.dart';

/// Provider onboarding — skills, experience, service area, availability.
/// No identity verification is part of this flow — the "Verified" badge is
/// granted by an administrator in the admin website, not earned here.
class ProviderOnboardingScreen extends StatefulWidget {
  const ProviderOnboardingScreen({super.key});

  @override
  State<ProviderOnboardingScreen> createState() =>
      _ProviderOnboardingScreenState();
}

class _ProviderOnboardingScreenState extends State<ProviderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _experienceController = TextEditingController();
  final _serviceAreaController = TextEditingController();
  final Set<ServiceCategory> _selectedSkills = {};
  final Set<String> _availableDays = {};
  bool _submitting = false;
  String? _error;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void dispose() {
    _phoneController.dispose();
    _experienceController.dispose();
    _serviceAreaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedSkills.isEmpty) {
      setState(() => _error = 'Select at least one skill.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await AuthService.instance.completeOnboarding(
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        providerProfile: ProviderProfile(
          skills: _selectedSkills.toList(),
          experienceYears: int.tryParse(_experienceController.text.trim()),
          serviceArea: _serviceAreaController.text.trim().isEmpty
              ? null
              : _serviceAreaController.text.trim(),
          availability: _availableDays.isEmpty
              ? null
              : _availableDays.join(', '),
        ),
      );
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(RouteNames.providerHome, (route) => false);
    } catch (e) {
      setState(() => _error = AuthService.friendlyMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Complete your provider profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Tell customers what you offer',
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 24),
                Text(
                  'Phone number (optional)',
                  style: AppTextStyles.labelLarge,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '98765 43210',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return Validators.phone(v);
                  },
                ),
                const SizedBox(height: 24),
                Text('Your skills', style: AppTextStyles.labelLarge),
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
                      selected: _selectedSkills.contains(
                        ServiceCategory.plumber,
                      ),
                      onTap: () => setState(() {
                        _toggleSkill(ServiceCategory.plumber);
                      }),
                    ),
                    _SkillChip(
                      label: 'Electrical',
                      icon: Icons.electrical_services,
                      color: AppColors.electrical,
                      selected: _selectedSkills.contains(
                        ServiceCategory.electrician,
                      ),
                      onTap: () => setState(() {
                        _toggleSkill(ServiceCategory.electrician);
                      }),
                    ),
                    _SkillChip(
                      label: 'Carpentry',
                      icon: Icons.chair_alt,
                      color: AppColors.carpentry,
                      selected: _selectedSkills.contains(
                        ServiceCategory.carpenter,
                      ),
                      onTap: () => setState(() {
                        _toggleSkill(ServiceCategory.carpenter);
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _experienceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Years of experience',
                    prefixIcon: Icon(Icons.workspace_premium_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _serviceAreaController,
                  decoration: const InputDecoration(
                    labelText: 'Service area',
                    hintText: 'e.g. Within 10 km of Koramangala',
                    prefixIcon: Icon(Icons.map_outlined),
                  ),
                  validator: (v) =>
                      Validators.required(v, field: 'Service area'),
                ),
                const SizedBox(height: 24),
                Text('Availability', style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _days
                      .map(
                        (d) => FilterChip(
                          label: Text(d),
                          selected: _availableDays.contains(d),
                          onSelected: (sel) => setState(() {
                            sel
                                ? _availableDays.add(d)
                                : _availableDays.remove(d);
                          }),
                        ),
                      )
                      .toList(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.error)),
                ],
                const SizedBox(height: 32),
                PrimaryButton(
                  label: 'Continue',
                  icon: Icons.arrow_forward_rounded,
                  loading: _submitting,
                  useGradient: true,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleSkill(ServiceCategory category) {
    _selectedSkills.contains(category)
        ? _selectedSkills.remove(category)
        : _selectedSkills.add(category);
  }
}

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
