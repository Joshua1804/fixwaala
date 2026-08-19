import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/user_model.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/error_messages.dart';
import '../custom_button.dart';
import '../remote_image.dart';

/// The "Profile" half of the profile screen: avatar header, editable name and
/// phone, then role-specific navigation tiles.
///
/// This replaces `_ProfileContent` and `_ProviderProfileContent`, which were
/// duplicates. Two bugs lived in both copies and were fixed in neither:
///
/// * Save discarded its own result — `user.copyWith(...)` was called and the
///   returned object thrown away, then a success snackbar was shown.
/// * The controllers were reassigned inside the builder, so any rebuild
///   (keyboard opening, theme change) wiped whatever had been typed.
///
/// Both are fixed here: saving awaits a real write, and seeding is owned by
/// [ProfileTabState] which only seeds when the identity actually changes.
class ProfileTab extends StatefulWidget {
  final AppUser? user;
  final TextEditingController nameController;
  final TextEditingController phoneController;

  /// Shown when the account has no name yet ("Customer User"/"Provider User").
  final String fallbackName;

  /// Optional status chip under the email — the provider's verified badge.
  final Widget? badge;

  /// Role-specific rows rendered beneath the editable fields.
  final List<Widget> tiles;

  /// Persists the edit. Returns normally on success; throwing surfaces the
  /// message inline instead of claiming the save worked. [photoUrl] is only
  /// non-null when called from the avatar picker; the name/phone save button
  /// always passes `null` (no photo change intended).
  final Future<void> Function(String name, String phone, String? photoUrl)
  onSave;

  const ProfileTab({
    super.key,
    required this.user,
    required this.nameController,
    required this.phoneController,
    required this.fallbackName,
    required this.onSave,
    this.badge,
    this.tiles = const [],
  });

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _isEditing = false;
  bool _isSaving = false;
  bool _uploadingPhoto = false;
  String? _error;

  Future<void> _handleSave() async {
    final user = widget.user;
    if (user == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(
        widget.nameController.text.trim(),
        widget.phoneController.text.trim(),
        null,
      );
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      // Stay in edit mode so the user does not lose what they typed.
      setState(() {
        _isSaving = false;
        _error = ErrorMessages.friendly(error);
      });
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final user = widget.user;
    if (user == null || _uploadingPhoto) return;
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingPhoto = true);
    final url = await CloudinaryService.instance.uploadImage(
      File(picked.path),
    );
    if (!mounted) return;

    if (url == null) {
      setState(() => _uploadingPhoto = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not upload photo. Try again.')),
      );
      return;
    }

    try {
      await widget.onSave(user.name ?? '', user.phone ?? '', url);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(ErrorMessages.friendly(error))));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  void _toggleEditing() {
    setState(() {
      _isEditing = !_isEditing;
      _error = null;
      if (!_isEditing) {
        // Cancelling restores the persisted values.
        widget.nameController.text = widget.user?.name ?? '';
        widget.phoneController.text = widget.user?.phone ?? '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = widget.user;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: user?.photoUrl != null
                          ? RemoteImage(url: user!.photoUrl!, fit: BoxFit.cover)
                          : const Icon(
                              Icons.person_rounded,
                              size: 36,
                              color: AppColors.primary,
                            ),
                    ),
                    if (_uploadingPhoto)
                      const Positioned.fill(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                user?.name?.isNotEmpty == true
                    ? user!.name!
                    : widget.fallbackName,
                style: AppTextStyles.headlineSmall,
              ),
              if (user?.email.isNotEmpty ?? false) ...[
                const SizedBox(height: 2),
                Text(user!.email, style: AppTextStyles.bodyMedium),
              ],
              if (widget.badge != null) ...[
                const SizedBox(height: 6),
                widget.badge!,
              ],
              if (user?.phone?.isNotEmpty ?? false) ...[
                const SizedBox(height: 4),
                Text(
                  '+91 ${user!.phone}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Basic Information', style: AppTextStyles.titleLarge),
            TextButton(
              onPressed: user == null || _isSaving ? null : _toggleEditing,
              child: Text(_isEditing ? 'Cancel' : 'Edit'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        EditableProfileField(
          label: 'Name',
          controller: widget.nameController,
          enabled: _isEditing && !_isSaving,
          isDark: isDark,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: 12),
        EditableProfileField(
          label: 'Phone',
          controller: widget.phoneController,
          enabled: _isEditing && !_isSaving,
          keyboardType: TextInputType.phone,
          isDark: isDark,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          onSubmitted: _isEditing ? (_) => _handleSave() : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _error!,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (_isEditing) ...[
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isSaving ? 'Saving…' : 'Save Changes',
            onPressed: _isSaving ? null : _handleSave,
          ),
        ],
        const SizedBox(height: 32),
        ...widget.tiles,
      ],
    );
  }
}

/// The labelled text field used for every editable profile row.
class EditableProfileField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final bool isDark;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  const EditableProfileField({
    super.key,
    required this.label,
    required this.controller,
    required this.enabled,
    required this.isDark,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? (isDark ? AppColors.cardDark : AppColors.surface)
                : AppColors.textHint.withValues(alpha: 0.05),
            border: border(AppColors.divider),
            enabledBorder: border(AppColors.divider.withValues(alpha: 0.5)),
            disabledBorder: border(AppColors.textHint.withValues(alpha: 0.1)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            hintText: label,
            hintStyle: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textHint,
            ),
          ),
          style: AppTextStyles.bodyMedium,
        ),
      ],
    );
  }
}
