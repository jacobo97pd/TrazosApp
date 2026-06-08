import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../core/theme.dart';
import '../models/zone_model.dart';

// Stream de todas las zonas de la ciudad activa
final zonesProvider = StreamProvider.autoDispose<List<ZoneModel>>((ref) {
  // TODO: filtrar por ciudad del usuario en lugar de traer todo
  return FirebaseFirestore.instance
      .collection('zones')
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) => ZoneModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// Convierte las zonas en Polygon de Google Maps para renderizar.
// Las zonas NO son interactivas: no consumen toques ni se pueden seleccionar.
final mapPolygonsProvider = Provider.autoDispose<Set<Polygon>>((ref) {
  final zonesAsync = ref.watch(zonesProvider);

  return zonesAsync.maybeWhen(
    data: (zones) => zones.map((zone) {
      final fillColor = _zoneColor(zone);
      return Polygon(
        polygonId:   PolygonId(zone.id),
        points:      zone.polygon,
        fillColor:   fillColor.withValues(alpha: 0.28),
        strokeColor: fillColor,
        strokeWidth: 1,
        consumeTapEvents: false,
      );
    }).toSet(),
    orElse: () => {},
  );
});

// Devuelve el color de fill según estado de la zona
Color _zoneColor(ZoneModel zone) {
  if (zone.isFree)     return AppColors.zoneFree;
  if (zone.isExpiring) return AppColors.zoneExpiring;
  if (zone.ownerType == OwnerType.club) return AppColors.zoneClub;
  return AppColors.zoneOwned;
}
