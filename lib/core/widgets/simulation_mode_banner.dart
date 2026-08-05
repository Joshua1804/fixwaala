import 'package:flutter/material.dart';

import '../services/firebase_service.dart';
import '../theme/app_text_styles.dart';

/// A persistent, unmissable warning that nothing is being saved.
///
/// When Firebase is unconfigured the app falls back to in-memory simulation:
/// it launches, every screen works, and all data vanishes on restart. That
/// state was previously signalled by a single `debugPrint`, which meant a
/// broken build was indistinguishable from a working one — including to
/// whoever was about to ship it.
class SimulationModeBanner extends StatelessWidget {
  /// The app content this banner sits above.
  final Widget child;

  const SimulationModeBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!FirebaseService.instance.isSimulated) return child;

    return Directionality(
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      child: Column(
        children: [
          Material(
            color: const Color(0xFFB3261E),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'DEMO MODE — nothing is saved. '
                        '${FirebaseService.instance.simulationReason ?? ''}',
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
