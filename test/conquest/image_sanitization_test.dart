import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:runrace/conquest/image_sanitization_service.dart';

void main() {
  const svc = ImageSanitizationService();

  Uint8List makePng(int w, int h) {
    final image = img.Image(width: w, height: h);
    img.fill(image, color: img.ColorRgb8(120, 30, 60));
    return Uint8List.fromList(img.encodePng(image));
  }

  test('re-encoda a JPEG válido y limita la resolución', () {
    final out = svc.sanitize(makePng(2000, 1000), contentType: 'image/png');
    expect(out.width, 1440); // lado mayor limitado
    expect(out.height, 720);
    // Salida decodable (JPEG, sin EXIF por re-encode).
    final decoded = img.decodeImage(out.bytes);
    expect(decoded, isNotNull);
    expect(out.thumbnail.length, lessThan(out.bytes.length));
  });

  test('genera thumbnail más pequeño', () {
    final out = svc.sanitize(makePng(1000, 1000));
    final thumb = img.decodeImage(out.thumbnail)!;
    expect(thumb.width, 320);
  });

  test('rechaza MIME no permitido', () {
    expect(
      () => svc.sanitize(makePng(10, 10), contentType: 'image/gif'),
      throwsA(isA<ImageSanitizationException>()),
    );
  });

  test('rechaza vacío', () {
    expect(() => svc.sanitize(Uint8List(0)),
        throwsA(isA<ImageSanitizationException>()));
  });

  test('rechaza por tamaño máximo', () {
    const small = ImageSanitizationService(maxInputBytes: 10);
    expect(() => small.sanitize(makePng(100, 100)),
        throwsA(isA<ImageSanitizationException>()));
  });

  test('rechaza bytes corruptos', () {
    expect(
      () => svc.sanitize(Uint8List.fromList([1, 2, 3, 4, 5])),
      throwsA(isA<ImageSanitizationException>()),
    );
  });
}
