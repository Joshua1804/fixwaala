import 'package:flutter/material.dart';

class ReportsManagementScreen extends StatelessWidget {
  const ReportsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports & disputes')),
      body: ListView.separated(
        itemCount: 3,
        separatorBuilder: (_, __) => const Divider(height: 0),
        itemBuilder: (context, i) => ListTile(
          leading: const Icon(Icons.report),
          title: Text('Report #$i'),
          subtitle: const Text('Reason: Poor quality of work'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: open report detail with resolve / restrict / suspend actions.
          },
        ),
      ),
    );
  }
}
