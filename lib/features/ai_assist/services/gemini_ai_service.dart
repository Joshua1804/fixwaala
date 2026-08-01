import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/enums.dart';
import '../models/clarifying_qa.dart';

/// Raw result of the first Gemini call: classification + follow-up questions.
class InitialAiResult {
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final double confidence;
  final bool safetyFlag;
  final List<String> questions;

  const InitialAiResult({
    required this.category,
    required this.complexity,
    required this.confidence,
    required this.safetyFlag,
    required this.questions,
  });
}

/// Raw result of the second Gemini call: final assessment after the
/// customer has answered the clarifying questions.
class FinalAiSummary {
  final ServiceCategory category;
  final ProblemComplexity complexity;
  final double confidence;
  final bool safetyFlag;
  final String summary;
  final List<String> recommendedEquipment;

  const FinalAiSummary({
    required this.category,
    required this.complexity,
    required this.confidence,
    required this.safetyFlag,
    required this.summary,
    required this.recommendedEquipment,
  });
}

/// Thin REST client for Gemini's `generateContent` endpoint. Every method
/// returns null on any failure (no API key, timeout, bad response) rather
/// than throwing, so callers can fall back to the rule-based classifier.
class GeminiAiService {
  GeminiAiService._();
  static final GeminiAiService instance = GeminiAiService._();

  static const _categoryNames = ['plumber', 'electrician', 'carpenter', 'unknown'];
  static const _complexityNames = ['low', 'medium', 'high'];

  String? get _apiKey {
    final key = dotenv.env['GEMINI_API_KEY'];
    return (key == null || key.trim().isEmpty) ? null : key.trim();
  }

  String get _model => dotenv.env['GEMINI_MODEL']?.trim().isNotEmpty == true
      ? dotenv.env['GEMINI_MODEL']!.trim()
      : 'gemini-2.5-flash';

  Future<Map<String, dynamic>?> _generate({
    required String prompt,
    required Map<String, dynamic> responseSchema,
  }) async {
    final apiKey = _apiKey;
    if (apiKey == null) return null;

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent?key=$apiKey',
    );
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': responseSchema,
      },
    });

    try {
      final response = await http
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        debugPrint('[GeminiAiService] HTTP ${response.statusCode}: ${response.body}');
        return null;
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final text = decoded['candidates']?[0]?['content']?['parts']?[0]?['text'] as String?;
      if (text == null) return null;
      return jsonDecode(text) as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      debugPrint('[GeminiAiService] Timeout: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('[GeminiAiService] Network error: $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('[GeminiAiService] Malformed response: $e');
      return null;
    } catch (e) {
      debugPrint('[GeminiAiService] Unexpected error: $e');
      return null;
    }
  }

  ServiceCategory _parseCategory(dynamic value) {
    final name = value?.toString();
    return ServiceCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ServiceCategory.unknown,
    );
  }

  ProblemComplexity _parseComplexity(dynamic value) {
    final name = value?.toString();
    return ProblemComplexity.values.firstWhere(
      (c) => c.name == name,
      orElse: () => ProblemComplexity.medium,
    );
  }

  double _parseConfidence(dynamic value) {
    final d = (value as num?)?.toDouble() ?? 0.5;
    return d.clamp(0.0, 1.0);
  }

  Future<InitialAiResult?> classifyAndGenerateQuestions({
    required String description,
    required List<String> imageUrls,
  }) async {
    final prompt =
        '''
You are a triage assistant for a home-repair marketplace. A customer described
a problem in their own words. Classify it and produce short clarifying
questions that will help a service provider (plumber, electrician, or
carpenter) arrive prepared with the right tools and parts, and help the
customer articulate their problem better.

Customer description: "$description"
Number of photos attached: ${imageUrls.length}

Categories are limited to: plumber, electrician, carpenter, unknown.
Complexity is low, medium, or high.
Generate between 2 and 4 clarifying questions, each answerable in one short
sentence, specific to this exact problem (not generic).
''';

    final schema = {
      'type': 'object',
      'properties': {
        'category': {'type': 'string', 'enum': _categoryNames},
        'complexity': {'type': 'string', 'enum': _complexityNames},
        'confidence': {'type': 'number'},
        'safetyFlag': {'type': 'boolean'},
        'questions': {
          'type': 'array',
          'items': {'type': 'string'},
          'minItems': 2,
          'maxItems': 4,
        },
      },
      'required': ['category', 'complexity', 'confidence', 'safetyFlag', 'questions'],
    };

    final json = await _generate(prompt: prompt, responseSchema: schema);
    if (json == null) return null;

    try {
      return InitialAiResult(
        category: _parseCategory(json['category']),
        complexity: _parseComplexity(json['complexity']),
        confidence: _parseConfidence(json['confidence']),
        safetyFlag: json['safetyFlag'] as bool? ?? false,
        questions: List<String>.from(json['questions'] ?? const []),
      );
    } catch (e) {
      debugPrint('[GeminiAiService] Failed to parse classification result: $e');
      return null;
    }
  }

  Future<FinalAiSummary?> summarize({
    required String description,
    required List<ClarifyingQa> qaPairs,
  }) async {
    final qaText = qaPairs
        .map((qa) => 'Q: ${qa.question}\nA: ${qa.answer}')
        .join('\n\n');

    final prompt =
        '''
A customer originally described a home-repair problem: "$description"

They then answered these follow-up questions:
$qaText

Based on all of this, produce a final structured assessment: confirmed
category, complexity, a short (1-2 sentence) human-readable problem summary,
a list of recommended tools/parts/equipment the assigned service provider
should bring, a confidence score, and a safety flag.

Categories are limited to: plumber, electrician, carpenter, unknown.
Complexity is low, medium, or high.
''';

    final schema = {
      'type': 'object',
      'properties': {
        'category': {'type': 'string', 'enum': _categoryNames},
        'complexity': {'type': 'string', 'enum': _complexityNames},
        'confidence': {'type': 'number'},
        'safetyFlag': {'type': 'boolean'},
        'summary': {'type': 'string'},
        'recommendedEquipment': {
          'type': 'array',
          'items': {'type': 'string'},
        },
      },
      'required': [
        'category',
        'complexity',
        'confidence',
        'safetyFlag',
        'summary',
        'recommendedEquipment',
      ],
    };

    final json = await _generate(prompt: prompt, responseSchema: schema);
    if (json == null) return null;

    try {
      return FinalAiSummary(
        category: _parseCategory(json['category']),
        complexity: _parseComplexity(json['complexity']),
        confidence: _parseConfidence(json['confidence']),
        safetyFlag: json['safetyFlag'] as bool? ?? false,
        summary: json['summary'] as String? ?? description,
        recommendedEquipment: List<String>.from(json['recommendedEquipment'] ?? const []),
      );
    } catch (e) {
      debugPrint('[GeminiAiService] Failed to parse summary result: $e');
      return null;
    }
  }
}
