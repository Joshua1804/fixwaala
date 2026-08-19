import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/routes/route_names.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/models/enums.dart';

const _maxPhotos = 5;

class _PhotoUpload {
  final File file;
  String? url;
  bool uploading = true;
  bool failed = false;

  _PhotoUpload({required this.file});
}

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _descriptionController = TextEditingController();
  final List<_PhotoUpload> _photos = [];
  final _picker = ImagePicker();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_photos.length >= _maxPhotos) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked == null) return;

    final photo = _PhotoUpload(file: File(picked.path));
    setState(() => _photos.add(photo));
    await _upload(photo);
  }

  Future<void> _upload(_PhotoUpload photo) async {
    final url = await CloudinaryService.instance.uploadImage(photo.file);
    if (!mounted) return;
    setState(() {
      photo.uploading = false;
      photo.url = url;
      photo.failed = url == null;
    });
  }

  void _removePhoto(_PhotoUpload photo) {
    setState(() => _photos.remove(photo));
  }

  bool get _isUploading => _photos.any((p) => p.uploading);

  /// Minimum useful description. Below this the AI has nothing to classify
  /// and a provider has nothing to prepare for.
  static const _minDescriptionLength = 15;

  String? _descriptionError;

  void _continue() {
    // There was no validator at all: an empty description went straight to
    // the AI, which then produced generic questions about nothing.
    final description = _descriptionController.text.trim();
    if (description.length < _minDescriptionLength) {
      setState(() {
        _descriptionError = description.isEmpty
            ? 'Please describe the problem so we can send the right person.'
            : 'Add a little more detail — what is wrong, and where?';
      });
      return;
    }

    setState(() => _descriptionError = null);
    final images = _photos
        .where((p) => p.url != null)
        .map((p) => p.url!)
        .toList();

    // The category the customer picked on the home grid, if any. Passing it
    // on lets the AI treat it as a strong prior rather than re-deriving the
    // category from scratch and potentially contradicting them.
    final seeded =
        (ModalRoute.of(context)?.settings.arguments
            as Map<String, dynamic>?)?['category'];

    Navigator.of(context).pushNamed(
      RouteNames.aiAssist,
      arguments: {
        'description': description,
        'images': images,
        if (seeded is ServiceCategory) 'seedCategory': seeded,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Describe the issue')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenHPad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_descriptionError != null) {
                  setState(() => _descriptionError = null);
                }
              },
              decoration: InputDecoration(
                labelText: "What's the problem?",
                hintText: 'e.g. Kitchen sink is leaking under the cabinet.',
                border: const OutlineInputBorder(),
                errorText: _descriptionError,
                helperText: 'The more detail, the better prepared they arrive.',
              ),
            ),
            const SizedBox(height: 16),
            if (_photos.isNotEmpty) ...[
              SizedBox(
                height: 84,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _PhotoThumbnail(
                    photo: _photos[i],
                    onRemove: () => _removePhoto(_photos[i]),
                    onRetry: () => _upload(_photos[i]),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            OutlinedButton.icon(
              onPressed: _photos.length >= _maxPhotos ? null : _pickImage,
              icon: const Icon(Icons.add_a_photo),
              label: Text('Add photos (${_photos.length}/$_maxPhotos)'),
            ),
            const Spacer(),
            PrimaryButton(
              label: 'Continue',
              loading: _isUploading,
              onPressed: _isUploading ? null : _continue,
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final _PhotoUpload photo;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  const _PhotoThumbnail({
    required this.photo,
    required this.onRemove,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(photo.file, fit: BoxFit.cover),
            ),
          ),
          if (photo.uploading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          if (photo.failed)
            Positioned.fill(
              child: GestureDetector(
                onTap: onRetry,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(
                    child: Icon(Icons.refresh, color: Colors.white),
                  ),
                ),
              ),
            ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
