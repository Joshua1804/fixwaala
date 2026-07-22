import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/payment_service.dart';

class SimulatedPaymentScreen extends StatefulWidget {
  const SimulatedPaymentScreen({super.key});

  @override
  State<SimulatedPaymentScreen> createState() =>
      _SimulatedPaymentScreenState();
}

class _SimulatedPaymentScreenState extends State<SimulatedPaymentScreen> {
  String _method = 'upi';
  bool _processing = false;

  Future<void> _pay() async {
    setState(() => _processing = true);
    final result = await PaymentService.instance.simulate(
      jobId: 'job-id-stub',
      amount: 400,
      method: _method,
    );
    if (!mounted) return;
    setState(() => _processing = false);
    Navigator.of(context)
        .pushReplacementNamed(RouteNames.rating, arguments: result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment (simulated)')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Amount due: ₹400',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            for (final method in const ['upi', 'card', 'cash'])
              RadioListTile<String>(
                value: method,
                groupValue: _method,
                onChanged: (v) => setState(() => _method = v!),
                title: Text(method.toUpperCase()),
              ),
            const Spacer(),
            PrimaryButton(
              label: _processing ? 'Processing...' : 'Pay now',
              loading: _processing,
              onPressed: _pay,
            ),
            const SizedBox(height: 8),
            const Text(
              'Simulated payment — no real money is moved.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
