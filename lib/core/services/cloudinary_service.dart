import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Thin REST client for Cloudinary's unsigned upload endpoint. Returns null
/// on any failure (missing config, timeout, non-200) rather than throwing,
/// so callers can treat a failed upload as "skip this photo".
class CloudinaryService {
  CloudinaryService._();
  static final CloudinaryService instance = CloudinaryService._();

  String? get _cloudName {
    final name = dotenv.env['CLOUDINARY_CLOUD_NAME'];
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  String? get _uploadPreset {
    final preset = dotenv.env['CLOUDINARY_UPLOAD_PRESET'];
    return (preset == null || preset.trim().isEmpty) ? null : preset.trim();
  }

  Future<String?> uploadImage(File file) async {
    final cloudName = _cloudName;
    final uploadPreset = _uploadPreset;
    if (cloudName == null || uploadPreset == null) return null;

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
