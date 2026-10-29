import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GeminiProductAnalysis {
  const GeminiProductAnalysis({
    required this.brand,
    required this.category,
    required this.packageType,
    required this.displayName,
    required this.packshotPrompt,
  });

  final String brand;
  final String category;
  final String packageType;
  final String displayName;
  final String packshotPrompt;

  factory GeminiProductAnalysis.fromJson(Map<String, dynamic> json) {
    return GeminiProductAnalysis(
      brand: json['brand'] as String? ?? '',
      category: json['category'] as String? ?? 'Ritel',
      packageType: json['package_type'] as String? ?? 'Kemasan Produk',
      displayName: json['display_name'] as String? ?? '',
      packshotPrompt: json['packshot_prompt'] as String? ?? '',
    );
  }
}

class GeminiService {
  static const String _prefApiKey = 'dpos_gemini_api_key';
  static const String _defaultApiKey =
      'AIzaSyBdHgblpDiZprzW701X7J-bIHRMf1NddYA';

  static const List<String> _candidateModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash',
    'gemini-3-flash-preview',
    'gemma-4-26b-a4b-it',
    'gemma-4-31b-it',
  ];

  final Dio _dio;

  GeminiService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 15),
              headers: {'Content-Type': 'application/json'},
            ),
          );

  Future<String> getApiKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final custom = prefs.getString(_prefApiKey);
      if (custom != null && custom.trim().isNotEmpty) return custom.trim();
    } catch (_) {}
    return _defaultApiKey;
  }

  Future<void> saveApiKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefApiKey, key.trim());
  }

  /// Sends raw prompt to candidate Gemini models with automatic fallback
  Future<String> generateText(String systemPrompt, String userMessage) {
    return generateChat(
      systemPrompt: systemPrompt,
      history: const [],
      userMessage: userMessage,
    );
  }

  /// Sends multi-turn chat conversation to Gemini with memory of previous turns
  Future<String> generateChat({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final apiKey = await getApiKey();

    final contents = <Map<String, dynamic>>[];
    for (final h in history) {
      final role = h['role'] == 'user' ? 'user' : 'model';
      final text = h['text']?.trim() ?? '';
      if (text.isNotEmpty) {
        contents.add({
          'role': role,
          'parts': [
            {'text': text}
          ],
        });
      }
    }
    contents.add({
      'role': 'user',
      'parts': [
        {'text': userMessage}
      ],
    });

    final requestBody = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': contents,
      'generationConfig': {'temperature': 0.5, 'maxOutputTokens': 1500},
    };

    DioException? lastException;

    for (final model in _candidateModels) {
      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey';
      try {
        final response = await _dio.post(url, data: requestBody);
        if (response.statusCode == 200) {
          final data = response.data as Map<String, dynamic>;
          final candidates = data['candidates'] as List?;
          if (candidates != null && candidates.isNotEmpty) {
            final content = candidates[0]['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List?;
            if (parts != null && parts.isNotEmpty) {
              return parts[0]['text'] as String? ?? '';
            }
          }
        }
      } on DioException catch (e) {
        lastException = e;
        debugPrint(
          'Gemini model $model failed (${e.response?.statusCode}), trying next...',
        );
        continue;
      }
    }

    if (lastException != null) {
      throw Exception('Gagal menghubungi Gemini: ${lastException.message}');
    }
    throw Exception('Tidak ada respon dari Gemini.');
  }

  /// Analyzes Indonesian cashier/retail product abbreviations into precise commercial photography packshots
  Future<GeminiProductAnalysis> analyzeProductForPackshot(
    String rawProductName, {
    String? category,
  }) async {
    const systemPrompt = '''
You are an expert Indonesian retail FMCG and F&B product analyst.
You specialize in converting abbreviated Indonesian cashier receipt names (e.g. "123 BENDERA COKLAT 300G", "INDOMIE GRG SPESIAL", "AQUA AIR MINERAL 600ML", "BODREX 20 TAB") into clear real-world products and accurate commercial studio packshot photography prompts.

Always respond ONLY with valid JSON with these exact keys:
{
  "brand": "Brand name, e.g. Frisian Flag Bendera",
  "category": "FMCG / Minuman / Makanan / Obat / Kafe",
  "package_type": "Kaleng / Box / Botol / Pouch / Blister / Cup Saji",
  "display_name": "Full proper Indonesian product name",
  "packshot_prompt": "English commercial product photography prompt under 40 words specifying the physical packaging (can/tin, bottle, pouch, box), studio lighting, clean background, sharp focus, packshot"
}
''';

    final userMessage =
        'Product Name: "$rawProductName"${category != null ? ', Category: "$category"' : ''}';

    try {
      final rawResponse = await generateText(systemPrompt, userMessage);
      // Clean markdown code blocks if present
      var jsonStr = rawResponse.trim();
      if (jsonStr.startsWith('```json')) {
        jsonStr = jsonStr.substring(7);
      } else if (jsonStr.startsWith('```')) {
        jsonStr = jsonStr.substring(3);
      }
      if (jsonStr.endsWith('```')) {
        jsonStr = jsonStr.substring(0, jsonStr.length - 3);
      }
      jsonStr = jsonStr.trim();

      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;
      return GeminiProductAnalysis.fromJson(decoded);
    } catch (e) {
      debugPrint(
        'Gemini analysis error: $e. Falling back to rule-based analysis.',
      );
      return _ruleBasedAnalysis(rawProductName, category);
    }
  }

  /// Rule-based fallback if offline or API unreachable
  GeminiProductAnalysis _ruleBasedAnalysis(
    String rawProductName,
    String? category,
  ) {
    final lower = rawProductName.toLowerCase();
    String packType = 'Kemasan Ritel';
    String promptDetail = 'commercial product packshot, clean studio lighting';

    if (lower.contains('300g') ||
        lower.contains('kaleng') ||
        lower.contains('can')) {
      packType = 'Kaleng / Can';
      promptDetail = 'tin can package packshot, studio lighting';
    } else if (lower.contains('botol') ||
        lower.contains('btl') ||
        lower.contains('600ml')) {
      packType = 'Botol / Bottle';
      promptDetail = 'bottle packaging packshot, studio lighting';
    } else if (lower.contains('box') ||
        lower.contains('dus') ||
        lower.contains('kotak')) {
      packType = 'Kotak Dus / Box';
      promptDetail = 'box packaging packshot, studio lighting';
    } else if (lower.contains('sachet') || lower.contains('pouch')) {
      packType = 'Pouch / Sachet';
      promptDetail = 'pouch package packshot, studio lighting';
    }

    return GeminiProductAnalysis(
      brand: '',
      category: category ?? 'Umum',
      packageType: packType,
      displayName: rawProductName,
      packshotPrompt:
          '$rawProductName, $promptDetail, centered, photorealistic, clean background',
    );
  }
}
