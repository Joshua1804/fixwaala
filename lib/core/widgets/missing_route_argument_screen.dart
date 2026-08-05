import 'package:flutter/material.dart';

import 'empty_state_widget.dart';

/// Shown when a screen is opened without the argument it needs.
///
/// Eight screens read `ModalRoute.of(context)!.settings.arguments as String`
/// directly inside `build()`. That is two unguarded failures in one line: the
/// `!` throws if there is no route, and the cast throws if the argument is
/// absent or the wrong type. Reaching any of them from a notification tap, a
/// deep link, or a restored navigation stack crashed the screen outright.
class MissingRouteArgumentScreen extends StatelessWidget {
  final String title;

  const MissingRouteArgumentScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: EmptyStateWidget(
        icon: Icons.link_off_rounded,
        title: "Couldn't open this",
        subtitle:
            'The link that brought you here is missing some information. '
            'Try opening it again from your requests.',
        actionLabel: Navigator.of(context).canPop() ? 'Go back' : null,
        onAction: Navigator.of(context).canPop()
            ? () => Navigator.of(context).pop()
            : null,
      ),
    );
  }
}
