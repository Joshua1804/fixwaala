import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/custom_button.dart';
import '../services/verification_service.dart';

class AadhaarEntryScreen extends StatefulWidget {
  const AadhaarEntryScreen({super.key});

  @override
  State<AadhaarEntryScreen> createState() => _AadhaarEntryScreenState();
}

class _AadhaarEntryScreenState extends State<AadhaarEntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _aadhaarController = TextEditingController();
  final _nameController = TextEditingController();
  bool _submitting = false;

  Future<void> _verify() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    final ok = await VerificationService.instance.verifyAadhaarSandbox(
      aadhaarNumber: _aadhaarController.text,
      fullName: _nameController.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok) {
      Navigator.of(context).pushNamed(RouteNames.selfieCapture);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aadhaar verification failed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aadhaar verification')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (as on Aadhaar)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => Validators.required(v, field: 'Name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aadhaarController,
                keyboardType: TextInputType.number,
                maxLength: 12,
                decoration: const InputDecoration(
                  labelText: 'Aadhaar number',
                  border: OutlineInputBorder(),
                ),
                validator: Validators.aadhaar,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sandbox verification — no real Aadhaar data is stored.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Verify Aadhaar',
                loading: _submitting,
                onPressed: _verify,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
