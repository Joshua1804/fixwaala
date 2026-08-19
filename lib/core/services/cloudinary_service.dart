import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Thin REST client for Cloudinary's unsigned upload endpoint. Returns null
/// on any failure (missing config, timeout, non-200) rather than throwing,
/// so callers can treat a failed upload as "skip this photo".
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  // Supplied at build time rather than read from a bundled `.env` asset.
  // Assets ship inside the APK as plain files, so anything placed there is
  // readable by anyone with the app — which is why the Gemini key that used to
  // live alongside these has moved server-side entirely.
  //
  // A cloud name and an *unsigned* upload preset are designed to be public
  // (browsers use them directly), so compiling them in is appropriate. Scope
  // the preset to a folder and rate-limit it in the Cloudinary console.
  //
  //   flutter build apk \
  //     --dart-define=CLOUDINARY_CLOUD_NAME=... \
  //     --dart-define=CLOUDINARY_UPLOAD_PRESET=...
  static const String _cloudNameDefine = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
  );
  static const String _uploadPresetDefine = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
  );

  String? get _cloudName =>
      _cloudNameDefine.trim().isEmpty ? null : _cloudNameDefine.trim();

  String? get _uploadPreset =>
      _uploadPresetDefine.trim().isEmpty ? null : _uploadPresetDefine.trim();

  /// Extensions Cloudinary's `image/upload` endpoint is actually used for
  /// here — rejecting anything else client-side avoids burning upload quota
  /// and bandwidth on a file that was never going to render as a photo.
  static const _allowedExtensions = {'jpg', 'jpeg', 'png', 'webp', 'heic'};

  /// Generous enough for a phone camera photo, small enough that one upload
  /// can't eat an outsized share of the unsigned preset's quota.
  static const _maxBytes = 10 * 1024 * 1024;

  Future<String?> uploadImage(File file) async {
    final cloudName = _cloudName;
    final uploadPreset = _uploadPreset;
    if (cloudName == null || uploadPreset == null) return null;

    final extension = file.path.split('.').last.toLowerCase();
    if (!_allowedExtensions.contains(extension)) {
      debugPrint('[CloudinaryService] Rejected file type: .$extension');
      return null;
    }

    final size = await file.length();
    if (size > _maxBytes) {
      debugPrint(
        '[CloudinaryService] Rejected file over ${_maxBytes ~/ (1024 * 1024)}MB: $size bytes',
      );
      return null;
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
    );

    try {
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', file.path));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 20),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        debugPrint(
          '[CloudinaryService] HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return decoded['secure_url'] as String?;
    } on TimeoutException catch (e) {
      debugPrint('[CloudinaryService] Timeout: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('[CloudinaryService] Network error: $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('[CloudinaryService] Malformed response: $e');
      return null;
    } catch (e) {
      debugPrint('[CloudinaryService] Unexpected error: $e');
      return null;
    }
  }
}
