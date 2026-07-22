import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';

class JobTrackingScreen extends StatelessWidget {
  const JobTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Provider on the way')),
      body: Column(
        children: [
          const Expanded(
            child: Center(
              child: Icon(Icons.map, size: 96, color: Colors.blueGrey),
              // TODO: replace with GoogleMap + live provider location marker.
            ),
          ),
          Card(
            margin: const EdgeInsets.all(16),
            child: Column(
              children: [
                const ListTile(
                  leading: CircleAvatar(child: Icon(Icons.person)),
                  title: Text('Rajesh Kumar'),
                  subtitle: Text('En route · ETA 6 min'),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context)
                              .pushNamed(RouteNames.sos),
                          icon: const Icon(Icons.emergency, color: Colors.red),
                          label: const Text('SOS'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context)
                              .pushReplacementNamed(RouteNames.inspection),
                          child: const Text('Provider arrived'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
