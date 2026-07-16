import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Genera el PNG (bytes) de un marcador circular con la foto de perfil del
/// corredor y un anillo del color de su territorio. Si no hay foto o falla la
/// descarga, dibuja las iniciales sobre un círculo del color.
///
/// El resultado se usa como icono de marcador en AdaptiveMap (Google/Apple).
Future<Uint8List> buildAvatarMarker({
  String? photoUrl,
  required String initials,
  required Color ringColor,
  double size = 132,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);
  final radius = size / 2;
  const ring = 7.0;
  final innerR = radius - ring;

  // Anillo de color + borde blanco.
  canvas.drawCircle(center, radius, Paint()..color = ringColor);
  canvas.drawCircle(center, radius - 2.5, Paint()..color = Colors.white);

  ui.Image? photo;
  if (photoUrl != null && photoUrl.trim().isNotEmpty) {
    try {
      final file = await DefaultCacheManager().getSingleFile(photoUrl.trim());
      photo = await decodeImageFromList(await file.readAsBytes());
    } catch (_) {/* sin foto: caemos a iniciales */}
  }

  if (photo != null) {
    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: center, radius: innerR)),
    );
    paintImage(
      canvas: canvas,
      rect: Rect.fromCircle(center: center, radius: innerR),
      image: photo,
      fit: BoxFit.cover,
    );
    canvas.restore();
  } else {
    canvas.drawCircle(center, innerR, Paint()..color = ringColor);
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  final image =
      await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Iniciales (máx 2) a partir de un nombre.
String initialsOf(String name) {
  final words =
      name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    return words.first.substring(0, 1).toUpperCase();
  }
  return (words.first.substring(0, 1) + words[1].substring(0, 1)).toUpperCase();
}
