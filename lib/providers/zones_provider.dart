import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/zone_model.dart';
import '../widgets/adaptive_map.dart';

// Stream de todas las zonas de la ciudad activa
final zonesProvider = StreamProvider.autoDispose<List<ZoneModel>>((ref) {
  // TODO: filtrar por ciudad del usuario en lugar de traer todo
  return FirebaseFirestore.instance.collection('zones').snapshots().map(
      (snap) => snap.docs
          .map((doc) => ZoneModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// Convierte las zonas en polígonos neutrales (AdaptiveMap los pinta en Google
// Maps o Apple Maps según la plataforma). Las zonas NO son interactivas.
final mapPolygonsProvider = Provider.autoDispose<List<MapPolygonData>>((ref) {
  final zonesAsync = ref.watch(zonesProvider);

  return zonesAsync.maybeWhen(
    data: (zones) => zones.map((zone) {
      final fillColor = _zoneColor(zone);
      return MapPolygonData(
        id: zone.id,
        points: [
          for (final p in zone.polygon) MapPoint(p.latitude, p.longitude),
        ],
        fillColor: fillColor.withValues(alpha: 0.34),
        strokeColor: fillColor,
      );
    }).toList(),
    orElse: () => const [],
  );
});

// Devuelve el color de fill según estado de la zona
Color _zoneColor(ZoneModel zone) {
  if (zone.isFree) return AppColors.zoneFree;
  if (zone.isExpiring) return AppColors.zoneExpiring;
  if (zone.ownerType == OwnerType.club) return AppColors.zoneClub;
  return AppColors.zoneOwned;
}
