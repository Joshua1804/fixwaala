import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../routes/route_names.dart';

/// True the first time a job reaches [JobStatus.workInProgress] — false on
/// every other status, and false again for a job already in [alreadyShown]
/// (an app-session-scoped dedupe set, not persisted — reopening the app
/// after a genuinely long job re-asking once is acceptable; re-asking on
/// every rebuild of the tracking screen is not).
bool shouldShowCheckpoint({
  required JobStatus status,
  required String jobId,
  required Set<String> alreadyShown,
}) {
  if (status != JobStatus.workInProgress) return false;
  return !alreadyShown.contains(jobId);
}

/// "Is everything going okay?" nudge shown once per job, to whichever side
/// (customer or provider) is looking at the job around the point work
/// actually starts. "No" hands off to the existing Report flow instead of
/// building a new escalation path.
class MidJobCheckpoint {
  MidJobCheckpoint._();

  static final Set<String> _shown = {};

  static void maybeShow(
    BuildContext context, {
    required String jobId,
    required JobStatus status,
    required String otherPartyId,
  }) {
    if (!shouldShowCheckpoint(
      status: status,
      jobId: jobId,
      alreadyShown: _shown,
    )) {
      return;
    }
    _shown.add(jobId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Is everything going okay?'),
          content: const Text('Just checking in now that work is underway.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Yes, all good'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.of(context).pushNamed(
                  RouteNames.report,
                  arguments: {'jobId': jobId, 'againstUserId': otherPartyId},
                );
              },
              child: const Text('No, report an issue'),
            ),
          ],
        ),
      );
    });
  }

  /// Test-only: clears the dedupe set between test cases.
  static void resetForTesting() => _shown.clear();
}
