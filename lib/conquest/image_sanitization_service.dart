import 'dart:typed_data';

import 'package:image/image.dart' as img;

class ImageSanitizationException implements Exception {
  ImageSanitizationException(this.reason);
  final String reason; // invalid_mime | too_large | corrupt | empty
  @override
  String toString() => 'ImageSanitizationException($reason)';
}

class SanitizedImage {
  const SanitizedImage({
    required this.bytes,
    required this.thumbnail,
    required this.width,
    required this.height,
  });
  final Uint8List bytes; // JPEG re-encodado (sin EXIF)
  final Uint8List thumbnail; // JPEG pequeño
  final int width;
  final int height;
}

/// Sanea imágenes antes de subirlas: valida tipo/tamaño, rechaza corruptas,
/// limita la resolución, RE-ENCODA a JPEG (lo que elimina cualquier metadato
/// EXIF, incluidas coordenadas) y genera un thumbnail. NO aplica espejo
/// (los selfies quedan como en Instagram Stories).
class ImageSanitizationService {
  const ImageSanitizationService({
    this.maxInputBytes = 12 * 1024 * 1024, // 12 MB de entrada
    this.maxDimension = 1440, // lado mayor máximo
    this.thumbDimension = 320,
    this.jpegQuality = 85,
  });

  final int maxInputBytes;
  final int maxDimension;
  final int thumbDimension;
  final int jpegQuality;

  static const _allowedMime = {'image/jpeg', 'image/png', 'image/webp'};

  SanitizedImage sanitize(
    Uint8List input, {
    String? contentType,
    bool mirror = false, // por defecto NO espejo
  }) {
    if (input.isEmpty) throw ImageSanitizationException('empty');
    if (input.length > maxInputBytes) {
      throw ImageSanitizationException('too_large');
    }
    if (contentType != null && !_allowedMime.contains(contentType)) {
      throw ImageSanitizationException('invalid_mime');
    }

    img.Image? decoded;
    try {
      decoded = img.decodeImage(input);
    } catch (_) {
      decoded = null;
    }
    if (decoded == null) throw ImageSanitizationException('corrupt');

    var image = img.bakeOrientation(decoded); // respeta orientación, quita tag
    if (mirror) image = img.flipHorizontal(image);

    // Limita la resolución del lado mayor.
    if (image.width > maxDimension || image.height > maxDimension) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxDimension)
          : img.copyResize(image, height: maxDimension);
    }

    final thumbSrc = image.width >= image.height
        ? img.copyResize(image, width: thumbDimension)
        : img.copyResize(image, height: thumbDimension);

    // encodeJpg NO conserva EXIF → metadatos (y coordenadas) eliminados.
    return SanitizedImage(
      bytes: img.encodeJpg(image, quality: jpegQuality),
      thumbnail: img.encodeJpg(thumbSrc, quality: 80),
      width: image.width,
      height: image.height,
    );
  }
}
