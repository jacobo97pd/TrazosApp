import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

enum OwnerType { solo, club }

class ZoneModel extends Equatable {
  const ZoneModel({
    required this.id,
    required this.name,
    required this.city,
    required this.polygon,
    required this.centroid,
    required this.points,
    this.ownerId,
    this.ownerName,
    this.ownerType,
    this.capturedAt,
    this.expiresAt,
    this.color,
  });

  final String  id;
  final String  name;
  final String  city;
  final List<LatLng> polygon;
  final LatLng  centroid;
  final int     points;
  final String? ownerId;
  final String? ownerName;
  final OwnerType? ownerType;
  final DateTime? capturedAt;
  final DateTime? expiresAt;
  final String? color; // hex del dueño

  bool get isFree      => ownerId == null;
  bool get isExpiring  => expiresAt != null &&
      expiresAt!.difference(DateTime.now()).inHours <= 24;

  factory ZoneModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;

    List<LatLng> parsePolygon(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((p) {
        final m = p as Map;
        return LatLng(
          (m['lat'] as num).toDouble(),
          (m['lng'] as num).toDouble(),
        );
      }).toList();
    }

    LatLng parseCentroid(dynamic raw) {
      if (raw is GeoPoint) return LatLng(raw.latitude, raw.longitude);
      return const LatLng(0, 0);
    }

    OwnerType? parseOwnerType(String? raw) => switch (raw) {
      'solo' => OwnerType.solo,
      'club' => OwnerType.club,
      _      => null,
    };

    return ZoneModel(
      id:         doc.id,
      name:       d['name'] as String? ?? '',
      city:       d['city'] as String? ?? '',
      polygon:    parsePolygon(d['polygon']),
      centroid:   parseCentroid(d['centroid']),
      points:     (d['points'] as num?)?.toInt() ?? 0,
      ownerId:    d['ownerId'] as String?,
      ownerName:  d['ownerName'] as String?,
      ownerType:  parseOwnerType(d['ownerType'] as String?),
      capturedAt: (d['capturedAt'] as Timestamp?)?.toDate(),
      expiresAt:  (d['expiresAt']  as Timestamp?)?.toDate(),
      color:      d['color'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'name':      name,
    'city':      city,
    'polygon':   polygon.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
    'centroid':  GeoPoint(centroid.latitude, centroid.longitude),
    'points':    points,
    if (ownerId   != null) 'ownerId':    ownerId,
    if (ownerName != null) 'ownerName':  ownerName,
    if (ownerType != null) 'ownerType':  ownerType!.name,
    if (capturedAt != null) 'capturedAt': Timestamp.fromDate(capturedAt!),
    if (expiresAt  != null) 'expiresAt':  Timestamp.fromDate(expiresAt!),
    if (color != null) 'color': color,
  };

  @override
  List<Object?> get props => [id, ownerId, expiresAt, color];
}
