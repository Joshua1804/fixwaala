import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Blocks a destructive/high-impact admin action behind an explicit confirm.
/// Returns `true` only if the user pressed the confirm button.
Future<bool> showAdminConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.error)
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A single-line-reason variant for actions that need a short justification
/// (suspend, reject, resolve-with-note). Returns the trimmed reason, or null
/// if cancelled or left empty.
Future<String?> showAdminReasonDialog(
  BuildContext context, {
  required String title,
  required String label,
  String confirmLabel = 'Confirm',
  bool requireNonEmpty = true,
}) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final canConfirm = !requireNonEmpty || controller.text.trim().isNotEmpty;
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(labelText: label),
            onChanged: (_) => setState(() {}),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: canConfirm
                  ? () => Navigator.of(context).pop(controller.text.trim())
                  : null,
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    ),
  );
  controller.dispose();
  return result;
}
