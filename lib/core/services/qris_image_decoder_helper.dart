import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';

import 'qris_dynamic_generator.dart';

/// Helper tangguh untuk mengekstrak kode barcode QRIS dari foto galeri HP
class QrisImageDecoderHelper {
  QrisImageDecoderHelper._();

  /// Mencoba membaca barcode QRIS dari file foto galeri dengan strategi bertahap:
  /// 1. Analisis langsung file asli (lossless)
  /// 2. Bounding crop area tengah (menghilangkan noise header/footer poster)
  /// 3. Bounding crop area tengah-atas (posisi umum QR pada banner)
  /// 4. Optimasi kontras & grayscale
  static Future<String?> decodeFromImageFile(File file) async {
    final controller = MobileScannerController();

    try {
      // ── STRATEGI 1: Analisis langsung foto asli ─────────────────────────
      try {
        final capture = await controller.analyzeImage(file.path);
        final code = _extractValidQris(capture);
        if (code != null) {
          debugPrint('✅ [QRIS Decoder] Strategy 1 (Direct) succeeded: $code');
          return code;
        }
      } catch (e) {
        debugPrint('[QRIS Decoder] Strategy 1 error: $e');
      }

      // Jika strategi 1 gagal, baca bytes gambar untuk dianalisis lebih lanjut
      final bytes = await file.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final tempDir = await getTemporaryDirectory();

      // ── STRATEGI 2: Crop Area Tengah Persegi (70% dimensi) ──────────────
      // Poster QRIS umumnya menempatkan QR code di tengah
      try {
        final side = (image.width < image.height ? image.width : image.height) * 0.75;
        final sideInt = side.round();
        final x = ((image.width - sideInt) / 2).round().clamp(0, image.width - sideInt);
        final y = ((image.height - sideInt) / 2).round().clamp(0, image.height - sideInt);

        final cropped = img.copyCrop(
          image,
          x: x,
          y: y,
          width: sideInt,
          height: sideInt,
        );

        final croppedPath = '${tempDir.path}/temp_qris_crop_center.png';
        final croppedFile = File(croppedPath);
        await croppedFile.writeAsBytes(img.encodePng(cropped));

        final capture = await controller.analyzeImage(croppedPath);
        try {
          await croppedFile.delete();
        } catch (_) {}

        final code = _extractValidQris(capture);
        if (code != null) {
          debugPrint('✅ [QRIS Decoder] Strategy 2 (Center Crop) succeeded: $code');
          return code;
        }
      } catch (e) {
        debugPrint('[QRIS Decoder] Strategy 2 error: $e');
      }

      // ── STRATEGI 3: Crop Area Tengah-Atas (Umum untuk Flyer m-Banking) ───
      // Banyak flyer bank (BCA/GoPay/Mandiri) menaruh QR di 20% - 70% tinggi gambar
      try {
        final cropWidth = (image.width * 0.85).round();
        final cropHeight = (image.height * 0.55).round();
        final x = ((image.width - cropWidth) / 2).round().clamp(0, image.width - cropWidth);
        final y = (image.height * 0.20).round().clamp(0, image.height - cropHeight);

        final cropped = img.copyCrop(
          image,
          x: x,
          y: y,
          width: cropWidth,
          height: cropHeight,
        );

        final croppedPath = '${tempDir.path}/temp_qris_crop_upper.png';
        final croppedFile = File(croppedPath);
        await croppedFile.writeAsBytes(img.encodePng(cropped));

        final capture = await controller.analyzeImage(croppedPath);
        try {
          await croppedFile.delete();
        } catch (_) {}

        final code = _extractValidQris(capture);
        if (code != null) {
          debugPrint('✅ [QRIS Decoder] Strategy 3 (Upper Crop) succeeded: $code');
          return code;
        }
      } catch (e) {
        debugPrint('[QRIS Decoder] Strategy 3 error: $e');
      }

      // ── STRATEGI 4: Grayscale + Kontras Tinggi ───────────────────────────
      try {
        final gray = img.grayscale(image);
        final contrasted = img.contrast(gray, contrast: 130);

        final grayPath = '${tempDir.path}/temp_qris_gray.png';
        final grayFile = File(grayPath);
        await grayFile.writeAsBytes(img.encodePng(contrasted));

        final capture = await controller.analyzeImage(grayPath);
        try {
          await grayFile.delete();
        } catch (_) {}

        final code = _extractValidQris(capture);
        if (code != null) {
          debugPrint('✅ [QRIS Decoder] Strategy 4 (Grayscale) succeeded: $code');
          return code;
        }
      } catch (e) {
        debugPrint('[QRIS Decoder] Strategy 4 error: $e');
      }

      return null;
    } finally {
      controller.dispose();
    }
  }

  static String? _extractValidQris(BarcodeCapture? capture) {
    if (capture == null || capture.barcodes.isEmpty) return null;
    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        // Cek apakah format valid QRIS EMVCo
        if (QrisDynamicGenerator.isValidQrisPayload(raw) || raw.startsWith('000201')) {
          return raw;
        }
      }
    }
    // Jika tidak ada yang strict EMVCo, kembalikan barcode pertama jika tidak kosong
    final fallback = capture.barcodes.first.rawValue?.trim();
    if (fallback != null && fallback.isNotEmpty && fallback.length >= 20) {
      return fallback;
    }
    return null;
  }
}
