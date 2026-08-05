import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

/// Puts a confirmed customer and provider in touch.
///
/// After matching, the customer saw a name and a dot on a map and nothing
/// else — no call, no chat, no "I'm two minutes away". Phone numbers were
/// collected at onboarding and surfaced to neither party. That is the most
/// common reason a field-service job fails on arrival: the provider cannot
/// find the flat, the gate is locked, nobody answers the door.
///
/// This hands off to the dialer. It is deliberately not an in-app call: the
/// number is only revealed once both sides are committed to the job.
///
/// **Note:** the number shown is the counterparty's real number. Masking it
/// behind a proxy is a telephony-provider integration (Exotel/Twilio) and is
/// tracked separately — until then, only call this once a job is assigned.
class ContactPartyButton extends StatelessWidget {
  /// The counterparty's phone number. A null or empty value renders an
  /// explanatory disabled state rather than a button that does nothing.
  final String? phoneNumber;

  /// Who is being called, for the label and the unavailable message.
  final String partyLabel;

  final bool outlined;

  const ContactPartyButton({
    super.key,
    required this.phoneNumber,
    required this.partyLabel,
    this.outlined = true,
  });

  Future<void> _call(BuildContext context) async {
    final digits = (phoneNumber ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;

    final uri = Uri(scheme: 'tel', path: digits);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the dialer. Number: $digits')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final available = (phoneNumber ?? '').trim().isNotEmpty;

    if (!available) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.phone_disabled_rounded,
            size: 16,
            color: AppColors.textHint,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'No phone number on file for this $partyLabel',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
            ),
          ),
        ],
      );
    }

    final label = 'Call $partyLabel';
    final icon = const Icon(Icons.phone_rounded, size: 18);

    return outlined
        ? OutlinedButton.icon(
            onPressed: () => _call(context),
            icon: icon,
            label: Text(label),
          )
        : FilledButton.icon(
            onPressed: () => _call(context),
            icon: icon,
            label: Text(label),
          );
  }
}
