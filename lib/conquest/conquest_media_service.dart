import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

import 'image_sanitization_service.dart';

class UploadedMedia {
  const UploadedMedia({required this.mediaUrl, required this.thumbnailUrl});
  final String mediaUrl;
  final String thumbnailUrl;
}

/// Sanea (quita EXIF, comprime, thumbnail) y sube la imagen a Storage con un
/// identificador GENERADO (nunca el nombre del usuario). Ruta privada por dueño.
class ConquestMediaService {
  ConquestMediaService({
    this.sanitizer = const ImageSanitizationService(),
    this.mirror = false, // selfie NO espejo
  });

  final ImageSanitizationService sanitizer;
  final bool mirror;
  final _uuid = const Uuid();

  Future<UploadedMedia> uploadImage({
    required String userId,
    required Uint8List bytes,
    String? contentType,
  }) async {
    final clean =
        sanitizer.sanitize(bytes, contentType: contentType, mirror: mirror);
    final id = _uuid.v4();
    final base = 'conquest_media/$userId/$id';

    final full = FirebaseStorage.instance.ref('$base.jpg');
    final thumb = FirebaseStorage.instance.ref('${base}_thumb.jpg');
    final meta = SettableMetadata(contentType: 'image/jpeg');

    await full.putData(clean.bytes, meta);
    await thumb.putData(clean.thumbnail, meta);

    return UploadedMedia(
      mediaUrl: await full.getDownloadURL(),
      thumbnailUrl: await thumb.getDownloadURL(),
    );
  }
}
