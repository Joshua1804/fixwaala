import 'package:flutter/material.dart';

class PerformanceScreen extends StatelessWidget {
  const PerformanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Performance')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ChartPlaceholder(title: 'Weekly jobs'),
          _ChartPlaceholder(title: 'Monthly earnings'),
          _ChartPlaceholder(title: 'Category distribution'),
          _ChartPlaceholder(title: 'Demand trends'),
        ],
      ),
    );
  }
}

class _ChartPlaceholder extends StatelessWidget {
  final String title;
  const _ChartPlaceholder({required this.title});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const SizedBox(
              height: 120,
              child: Center(
                child: Text('[chart placeholder — plug in fl_chart]'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
