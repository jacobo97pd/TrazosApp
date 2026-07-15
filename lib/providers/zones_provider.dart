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

// Polígonos de TODAS las zonas para pintarlas en el mapa y en la carrera:
//  - Libres: contorno limpio con relleno muy suave (objetivo visible, sin el
//    "manchón" gris de antes) para saber dónde correr y capturar.
//  - Conquistadas: relleno translúcido con el color del dueño (solo/club) para
//    que todos vean quién domina cada zona.
// AdaptiveMap las pinta en Google Maps o Apple Maps según la plataforma.
final zonePolygonsProvider = Provider.autoDispose<List<MapPolygonData>>((ref) {
  final zonesAsync = ref.watch(zonesProvider);

  return zonesAsync.maybeWhen(
    data: (zones) => zones.map((zone) {
      final color = _zoneColor(zone);
      // Las libres apenas se rellenan (solo se marca el borde); las tomadas se
      // rellenan más para que destaque el territorio conquistado.
      final fillAlpha = zone.isFree ? 0.10 : 0.34;
      return MapPolygonData(
        id: zone.id,
        points: [
          for (final p in zone.polygon) MapPoint(p.latitude, p.longitude),
        ],
        fillColor: color.withValues(alpha: fillAlpha),
        strokeColor: color.withValues(alpha: zone.isFree ? 0.9 : 1.0),
        strokeWidth: zone.isFree ? 2 : 3,
      );
    }).toList(),
    orElse: () => const [],
  );
});

// Color de la zona según su estado. Las libres usan el acento (rosa) para que
// se vean como objetivo capturable en mapa claro (Apple) u oscuro (Google).
Color _zoneColor(ZoneModel zone) {
  if (zone.isFree) return AppColors.accent;
  if (zone.isExpiring) return AppColors.zoneExpiring;
  if (zone.ownerType == OwnerType.club) return AppColors.zoneClub;
  return AppColors.zoneOwned;
}
