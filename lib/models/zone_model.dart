import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

enum OwnerType { solo, club }

/// Territorio conquistado por un jugador. La geometría se guarda como GeoJSON
/// (Polygon o MultiPolygon, con posibles agujeros) en `geometryJson`.
class ZoneModel extends Equatable {
  const ZoneModel({
    required this.id,
    required this.geometryJson,
    this.ownerId,
    this.ownerName,
    this.ownerType,
    this.areaM2 = 0,
    this.color,
    this.capturedAt,
    this.expiresAt,
  });

  final String id;
  final String geometryJson;
  final String? ownerId;
  final String? ownerName;
  final OwnerType? ownerType;
  final double areaM2;
  final String? color;
  final DateTime? capturedAt;
  final DateTime? expiresAt;

  bool get isFree => ownerId == null;
  bool get isExpiring =>
      expiresAt != null &&
      expiresAt!.difference(DateTime.now()).inHours <= 24;

  factory ZoneModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;

    OwnerType? parseOwnerType(String? raw) => switch (raw) {
          'solo' => OwnerType.solo,
          'club' => OwnerType.club,
          _ => null,
        };

    return ZoneModel(
      id:          doc.id,
      geometryJson: d['geometryJson'] as String? ?? '',
      ownerId:     d['ownerId'] as String?,
      ownerName:   d['ownerName'] as String?,
      ownerType:   parseOwnerType(d['ownerType'] as String?),
      areaM2:      (d['areaM2'] as num?)?.toDouble() ?? 0,
      color:       d['color'] as String?,
      capturedAt:  (d['capturedAt'] as Timestamp?)?.toDate(),
      expiresAt:   (d['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [id, ownerId, geometryJson, expiresAt, color];
}
