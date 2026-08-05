import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../core/models/enums.dart';
import '../../../core/services/firebase_service.dart';
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

/// Client for AI triage, in one of two modes.
///
/// **Proxy mode** (preferred): calls the deployed `aiTriage` Cloud Function,
/// which holds the Gemini key server-side and authenticates callers by
/// Firebase ID token. This is the only mode safe to ship in a build anyone
/// else will install.
///
/// **Direct mode** (dev only): calls `generativelanguage.googleapis.com`
/// straight from the app, with the key compiled in via `--dart-define`. This
/// exists because the proxy requires the project to be on Firebase's Blaze
/// plan — Cloud Functions v2 needs a billing account attached even at zero
/// usage — and this project is deliberately staying on Spark while it is a
/// local implementation exercise, not a release.
///
/// **Direct mode reintroduces the exact defect proxy mode was built to close:
/// a key compiled into the APK is recoverable from any build with `unzip`.**
/// It is gated behind an explicit dart-define specifically so it is never on
/// by accident — nobody sets `GEMINI_API_KEY` without deciding to. Never
/// ship a build with `--dart-define=GEMINI_API_KEY=...` to anyone; use a key
/// you are prepared to delete, and delete it before this app is distributed.
///
/// Every method still returns null on any failure — unconfigured, timeout,
/// bad response — so callers fall back to the rule-based classifier rather
/// than blocking the customer's request.
class GeminiAiService {
  GeminiAiService._();
  static final GeminiAiService instance = GeminiAiService._();

  /// Endpoint of the deployed proxy:
  /// ```
  /// flutter build apk --dart-define=AI_PROXY_URL=https://<region>-<project>.cloudfunctions.net/aiTriage
  /// ```
  /// A URL is not a secret, so compiling it in is fine.
  static const String _proxyUrl = String.fromEnvironment('AI_PROXY_URL');

  /// Direct-mode key. See the class doc before setting this on a build you
  /// intend to hand to anyone.
  static const String _directApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
  );

  static const String _directModel = 'gemini-2.5-flash';

  static const _categoryNames = [
    'plumber',
    'electrician',
    'carpenter',
    'unknown',
  ];
  static const _complexityNames = ['low', 'medium', 'high'];

  bool get _proxyConfigured => _proxyUrl.trim().isNotEmpty;
  bool get _directConfigured => _directApiKey.trim().isNotEmpty;

  /// True when either mode was compiled in. Callers use this to explain
  /// *why* AI assist is unavailable instead of failing silently.
  bool get isConfigured => _proxyConfigured || _directConfigured;

  Future<Map<String, dynamic>?> _generate({
    required String prompt,
    required Map<String, dynamic> responseSchema,
  }) async {
    if (_proxyConfigured) {
      return _generateViaProxy(prompt: prompt, responseSchema: responseSchema);
    }
    if (_directConfigured) {
      return _generateDirect(prompt: prompt, responseSchema: responseSchema);
    }
    debugPrint(
      '[GeminiAiService] Neither AI_PROXY_URL nor GEMINI_API_KEY compiled '
      'in; falling back to the rule-based classifier.',
    );
    return null;
  }

  Future<Map<String, dynamic>?> _generateViaProxy({
    required String prompt,
    required Map<String, dynamic> responseSchema,
  }) async {
    // The proxy authorises per user, so an extracted build cannot be used to
    // burn quota anonymously.
    final idToken = await FirebaseService.instance.auth.currentUser
        ?.getIdToken();
    if (idToken == null) {
      debugPrint('[GeminiAiService] Not signed in; skipping AI assist.');
      return null;
    }

    final body = jsonEncode({
      'prompt': prompt,
      'responseSchema': responseSchema,
    });

    try {
      final response = await http
          .post(
            Uri.parse(_proxyUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $idToken',
            },
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint(
          '[GeminiAiService] HTTP ${response.statusCode}: ${response.body}',
        );
        return null;
      }
      return jsonDecode(response.body) as Map<String, dynamic>;
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

  /// Calls Gemini with no intermediary. Same request shape `functions/index.js`
  /// sends server-side, minus the auth and prompt-length checks a proxy would
  /// enforce — there is no server here to enforce them.
  Future<Map<String, dynamic>?> _generateDirect({
    required String prompt,
    required Map<String, dynamic> responseSchema,
  }) async {
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$_directModel:generateContent?key=$_directApiKey',
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
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint(
          '[GeminiAiService] Direct HTTP ${response.statusCode}: '
          '${response.body}',
        );
        return null;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final text =
          payload['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
      if (text == null || text.isEmpty) {
        debugPrint('[GeminiAiService] Direct call returned no text.');
        return null;
      }
      return jsonDecode(text) as Map<String, dynamic>;
    } on TimeoutException catch (e) {
      debugPrint('[GeminiAiService] Direct timeout: $e');
      return null;
    } on SocketException catch (e) {
      debugPrint('[GeminiAiService] Direct network error: $e');
      return null;
    } on FormatException catch (e) {
      debugPrint('[GeminiAiService] Direct malformed response: $e');
      return null;
    } catch (e) {
      debugPrint('[GeminiAiService] Direct unexpected error: $e');
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
      'required': [
        'category',
        'complexity',
        'confidence',
        'safetyFlag',
        'questions',
      ],
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
        recommendedEquipment: List<String>.from(
          json['recommendedEquipment'] ?? const [],
        ),
      );
    } catch (e) {
      debugPrint('[GeminiAiService] Failed to parse summary result: $e');
      return null;
    }
  }
}
