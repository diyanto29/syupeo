import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

class CompressedProductImage {
  const CompressedProductImage({
    required this.bytes,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final String fileName;
  final String contentType;

  int get sizeInBytes => bytes.lengthInBytes;
}

class ProductImageCompressionHelper {
  ProductImageCompressionHelper._();

  // Dioptimasi untuk layar kasir HP & Tablet:
  // 640px sangat tajam di layar Retina 2x/3x, namun ukuran file hemat hingga ~85%.
  static const List<int> _maxLongestSides = [640, 512, 400];
  static const List<int> _jpegQualities = [78, 70, 62, 54, 46];
  // Target maksimal 70 KB per foto (menghemat ~85% storage & bandwidth dibanding 450 KB):
  static const int _targetMaxBytes = 70 * 1024;

  static CompressedProductImage compress({
    required Uint8List bytes,
    required String originalFileName,
  }) {
    final decodedImage = img.decodeImage(bytes);
    if (decodedImage == null) {
      return CompressedProductImage(
        bytes: bytes,
        fileName: originalFileName,
        contentType:
            lookupMimeType(originalFileName, headerBytes: bytes) ??
            'application/octet-stream',
      );
    }

    final flattenedImage = _flattenIfNeeded(decodedImage);
    Uint8List? bestBytes;

    for (final maxLongestSide in _maxLongestSides) {
      final resizedImage = _resizeToLongestSide(flattenedImage, maxLongestSide);
      for (final quality in _jpegQualities) {
        final encodedBytes = img.encodeJpg(resizedImage, quality: quality);
        bestBytes = encodedBytes;
        if (encodedBytes.lengthInBytes <= _targetMaxBytes) {
          return CompressedProductImage(
            bytes: encodedBytes,
            fileName: _buildCompressedFileName(originalFileName),
            contentType: 'image/jpeg',
          );
        }
      }
    }

    // Jika semua permutasi melebihi target, gunakan hasil kompresi terkecil
    // atau encode hasil resize 480px pada kualitas 60%.
    final fallbackBytes = bestBytes ??
        img.encodeJpg(
          _resizeToLongestSide(flattenedImage, 480),
          quality: 60,
        );

    return CompressedProductImage(
      bytes: fallbackBytes,
      fileName: _buildCompressedFileName(originalFileName),
      contentType: 'image/jpeg',
    );
  }

  static img.Image _flattenIfNeeded(img.Image source) {
    if (!source.hasAlpha) {
      return source;
    }

    final flattened = img.Image(
      width: source.width,
      height: source.height,
      numChannels: 3,
    );
    img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(flattened, source);
    return flattened;
  }

  static img.Image _resizeToLongestSide(img.Image source, int maxLongestSide) {
    final longestSide = source.width > source.height
        ? source.width
        : source.height;
    if (longestSide <= maxLongestSide) {
      return source;
    }

    if (source.width >= source.height) {
      return img.copyResize(
        source,
        width: maxLongestSide,
        interpolation: img.Interpolation.average,
      );
    }

    return img.copyResize(
      source,
      height: maxLongestSide,
      interpolation: img.Interpolation.average,
    );
  }

  static String _buildCompressedFileName(String originalFileName) {
    final trimmed = originalFileName.trim();
    final dotIndex = trimmed.lastIndexOf('.');
    final baseName = dotIndex > 0 ? trimmed.substring(0, dotIndex) : trimmed;
    final normalizedBaseName = baseName.isEmpty ? 'product-image' : baseName;
    return '$normalizedBaseName.jpg';
  }
}
