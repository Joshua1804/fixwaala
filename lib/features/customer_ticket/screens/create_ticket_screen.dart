import 'package:flutter/material.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/widgets/custom_button.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _descriptionController = TextEditingController();
  final List<String> _imagePaths = [];

  Future<void> _pickImage() async {
    // TODO: pick image, append to _imagePaths.
    setState(() => _imagePaths.add('placeholder'));
  }

  void _continue() {
    Navigator.of(context).pushNamed(
      RouteNames.aiAssist,
      arguments: {
        'description': _descriptionController.text,
        'images': _imagePaths,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe the issue')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: "What's the problem?",
                hintText: 'e.g. Kitchen sink is leaking under the cabinet.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.add_a_photo),
              label: Text('Add photos (${_imagePaths.length})'),
            ),
            const Spacer(),
            PrimaryButton(label: 'Continue', onPressed: _continue),
          ],
        ),
      ),
    );
  }
}
