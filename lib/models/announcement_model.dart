import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipo de anuncio del tablón. Controla icono/color en la UI.
/// En Firestore es el campo `type` (string): 'ganador' | 'club' | 'evento' | 'aviso'.
enum AnnouncementType { ganador, club, evento, aviso }

AnnouncementType _typeFrom(String? raw) => switch (raw) {
      'ganador' => AnnouncementType.ganador,
      'club'    => AnnouncementType.club,
      'evento'  => AnnouncementType.evento,
      _         => AnnouncementType.aviso,
    };

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.imageUrl,
    this.createdAt,
    this.pinned = false,
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementType type;
  final String? imageUrl;
  final DateTime? createdAt;
  final bool pinned;

  factory AnnouncementModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AnnouncementModel(
      id:        doc.id,
      title:     d['title']    as String? ?? '',
      body:      d['body']     as String? ?? '',
      type:      _typeFrom(d['type'] as String?),
      imageUrl:  d['imageUrl'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      pinned:    d['pinned']   as bool? ?? false,
    );
  }
}
