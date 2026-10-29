import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'gemini_service.dart';

enum AiImageStyle {
  retailPackshot, // Kemasan Ritel / Packshot (Kaleng, Box, Botol, Pouch)
  studio,         // Studio Bersih
  cafe,           // Kafe / Meja Kayu
  aesthetic,      // Modern Estetik
  luxury,         // Mewah / Sinematik
}

class AiProductImageService {
  AiProductImageService({
    Dio? dio,
    GeminiService? geminiService,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 40),
                sendTimeout: const Duration(seconds: 20),
                headers: {
                  'User-Agent':
                      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                  'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
                },
              ),
            ),
        _gemini = geminiService ?? GeminiService();

  final Dio _dio;
  final GeminiService _gemini;

  static const Map<AiImageStyle, String> styleLabels = {
    AiImageStyle.retailPackshot: '📦 Kemasan Ritel (Packshot)',
    AiImageStyle.studio: '🏢 Studio Bersih',
    AiImageStyle.cafe: '☕ Kafe / Meja Kayu',
    AiImageStyle.aesthetic: '🌿 Modern Estetik',
    AiImageStyle.luxury: '✨ Mewah / Sinematik',
  };

  static const Map<AiImageStyle, String> styleKeywords = {
    AiImageStyle.retailPackshot:
        'commercial product packaging packshot, crisp retail branding label, clean white studio background, studio lights',
    AiImageStyle.studio:
        'clean white studio background, soft shadows, commercial catalog photography',
    AiImageStyle.cafe:
        'cafe wooden table background, warm bokeh, appetizing food presentation',
    AiImageStyle.aesthetic:
        'modern aesthetic pastel background, soft natural sunlight shadows',
    AiImageStyle.luxury:
        'dark elegant slate background, cinematic rim lighting, gourmet presentation',
  };

  /// Uses Gemini to analyze Indonesian cashier product abbreviations
  Future<GeminiProductAnalysis> analyzeProduct(
    String productName, {
    String? category,
  }) async {
    return await _gemini.analyzeProductForPackshot(
      productName,
      category: category,
    );
  }

  /// Builds a high-adherence commercial photography prompt
  String buildPrompt({
    required String productName,
    GeminiProductAnalysis? analysis,
    String? customNotes,
    AiImageStyle style = AiImageStyle.retailPackshot,
    bool simplified = false,
  }) {
    if (analysis != null &&
        analysis.packshotPrompt.isNotEmpty &&
        style == AiImageStyle.retailPackshot) {
      final notes = customNotes != null && customNotes.trim().isNotEmpty
          ? ', ${customNotes.trim()}'
          : '';
      return '${analysis.packshotPrompt}$notes';
    }

    final cleanName = productName.trim();
    if (simplified) {
      return '$cleanName, commercial product photo, studio lighting, centered';
    }

    final styleDesc =
        styleKeywords[style] ?? styleKeywords[AiImageStyle.retailPackshot]!;
    final notes = customNotes != null && customNotes.trim().isNotEmpty
        ? ', ${customNotes.trim()}'
        : '';

    return '$cleanName, product photography, $styleDesc$notes, centered, photorealistic, sharp focus';
  }

  /// Generates the direct URL for image rendering
  String getImageUrl({
    required String prompt,
    int? seed,
  }) {
    final finalSeed = seed ?? Random().nextInt(1000000);
    final encodedPrompt = Uri.encodeComponent(prompt);
    return 'https://image.pollinations.ai/prompt/$encodedPrompt?width=512&height=512&seed=$finalSeed&nologo=true';
  }

  /// Downloads the generated AI image as raw bytes with automatic retry
  Future<Uint8List> generateImageBytes({
    required String productName,
    GeminiProductAnalysis? analysis,
    String? category,
    String? customNotes,
    AiImageStyle style = AiImageStyle.retailPackshot,
    int? seed,
    void Function(int received, int total)? onProgress,
  }) async {
    final cleanName = productName.trim();
    if (cleanName.isEmpty) {
      throw Exception('Nama produk tidak boleh kosong.');
    }

    // Step 1: Use Gemini analysis if not already provided
    GeminiProductAnalysis? productAnalysis = analysis;
    if (productAnalysis == null && style == AiImageStyle.retailPackshot) {
      try {
        productAnalysis = await analyzeProduct(cleanName, category: category);
      } catch (e) {
        debugPrint('Gemini analysis failed: $e, using raw prompt.');
      }
    }

    // Attempt 1: Enriched Gemini packshot prompt
    final prompt1 = buildPrompt(
      productName: cleanName,
      analysis: productAnalysis,
      customNotes: customNotes,
      style: style,
      simplified: false,
    );

    try {
      return await _fetchBytes(prompt1, seed: seed, onProgress: onProgress);
    } catch (_) {
      // Attempt 2: Simplified fallback prompt with a new random seed
      final fallbackSeed = Random().nextInt(1000000);
      final prompt2 = buildPrompt(
        productName: cleanName,
        analysis: productAnalysis,
        customNotes: customNotes,
        style: style,
        simplified: true,
      );

      try {
        return await _fetchBytes(prompt2,
            seed: fallbackSeed, onProgress: onProgress);
      } catch (e2) {
        throw Exception(
          'Server render AI sedang sibuk. Silakan coba tekan "Coba Lagi" beberapa saat lagi.',
        );
      }
    }
  }

  Future<Uint8List> _fetchBytes(
    String prompt, {
    int? seed,
    void Function(int received, int total)? onProgress,
  }) async {
    final url = getImageUrl(prompt: prompt, seed: seed);

    final response = await _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: onProgress,
    );

    if (response.data == null || response.data!.isEmpty) {
      throw Exception('Data gambar kosong.');
    }

    return Uint8List.fromList(response.data!);
  }
}
