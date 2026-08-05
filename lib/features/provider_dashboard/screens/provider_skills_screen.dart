import 'package:flutter/material.dart';

import '../../../core/models/enums.dart';
import '../../../core/models/user_model.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/error_messages.dart';
import '../../../core/widgets/async_state_builder.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/service_category_ui.dart';
import '../../auth/services/auth_service.dart';

/// Lets a provider change the skills and availability they signed up with.
///
/// These were collected once during onboarding and then frozen — there was no
/// screen anywhere to edit them. A provider who learned a new trade, or who
/// picked the wrong category on their first run, had no way to fix it, and
/// skills are what the entire broadcast filter matches on.
class ProviderSkillsScreen extends StatefulWidget {
  const ProviderSkillsScreen({super.key});

  @override
  State<ProviderSkillsScreen> createState() => _ProviderSkillsScreenState();
}

class _ProviderSkillsScreenState extends State<ProviderSkillsScreen> {
  /// Selectable trades. `unknown` is an internal classification fallback, not
  /// something a provider can offer.
  static const _selectable = [
    ServiceCategory.plumber,
    ServiceCategory.electrician,
    ServiceCategory.carpenter,
  ];

  Set<ServiceCategory>? _skills;
  final TextEditingController _availability = TextEditingController();
  final TextEditingController _serviceArea = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _availability.dispose();
    _serviceArea.dispose();
    super.dispose();
  }

  void _seed(AppUser? user) {
    if (_seeded || user == null) return;
    _seeded = true;
    final profile = user.providerProfile;
    _skills = {...?profile?.skills};
    _availability.text = profile?.availability ?? '';
    _serviceArea.text = profile?.serviceArea ?? '';
  }

  Future<void> _save(AppUser user) async {
    final skills = _skills ?? {};
    if (skills.isEmpty) {
      setState(
        () => _error =
            'Choose at least one skill — this is what decides which jobs '
            'reach you.',
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final current = user.providerProfile ?? const ProviderProfile();
      await AuthService.instance.updateProviderProfile(
        current.copyWith(
          skills: skills.toList(),
          availability: _availability.text.trim(),
          serviceArea: _serviceArea.text.trim(),
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Skills updated')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = ErrorMessages.friendly(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Skills & availability')),
      body: AsyncStateBuilder.stream<AppUser?>(
        stream: AuthService.instance.currentUserStream,
        data: (context, user) {
          _seed(user);
          if (user == null) {
            return const Center(child: Text('Please sign in.'));
          }
          final selected = _skills ?? {};

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text('Skills', style: AppTextStyles.titleLarge),
              const SizedBox(height: 4),
              Text(
                'You only receive requests in the categories you select.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              ..._selectable.map(
                (category) => CheckboxListTile(
                  value: selected.contains(category),
                  onChanged: _saving
                      ? null
                      : (checked) => setState(() {
                          if (checked == true) {
                            selected.add(category);
                          } else {
                            selected.remove(category);
                          }
                          _skills = selected;
                          _error = null;
                        }),
                  title: Text(ServiceCategoryUi.label(category)),
                  secondary: Icon(
                    ServiceCategoryUi.icon(category),
                    color: AppColors.primary,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(height: 20),
              Text('Availability', style: AppTextStyles.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _availability,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'When can you take jobs?',
                  hintText: 'e.g. Weekdays 9am–7pm',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _serviceArea,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Service area',
                  hintText: 'e.g. Andheri West and nearby',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _saving ? 'Saving…' : 'Save changes',
                onPressed: _saving ? null : () => _save(user),
              ),
            ],
          );
        },
      ),
    );
  }
}
