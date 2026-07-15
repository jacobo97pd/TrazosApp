import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../models/zone_model.dart';
import '../widgets/adaptive_map.dart';

// Stream de todos los territorios.
final zonesProvider = StreamProvider.autoDispose<List<ZoneModel>>((ref) {
  return FirebaseFirestore.instance.collection('zones').snapshots().map(
      (snap) => snap.docs
          .map((doc) => ZoneModel.fromFirestore(
              doc as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

// Un anillo exterior con sus agujeros (para pintar en el mapa).
typedef _Ring = ({List<MapPoint> outer, List<List<MapPoint>> holes});

// Convierte los territorios (GeoJSON) en polígonos para AdaptiveMap. Cada
// territorio puede ser un multipolígono → varios MapPolygonData.
final zonePolygonsProvider = Provider.autoDispose<List<MapPolygonData>>((ref) {
  final zonesAsync = ref.watch(zonesProvider);

  return zonesAsync.maybeWhen(
    data: (zones) {
      final out = <MapPolygonData>[];
      for (final zone in zones) {
        final color = _zoneColor(zone);
        final fillAlpha = zone.isFree ? 0.10 : 0.34;
        final rings = _parseGeometry(zone.geometryJson);
        for (var i = 0; i < rings.length; i++) {
          out.add(MapPolygonData(
            id: '${zone.id}_$i',
            points: rings[i].outer,
            holes: rings[i].holes,
            fillColor: color.withValues(alpha: fillAlpha),
            strokeColor: color.withValues(alpha: zone.isFree ? 0.9 : 1.0),
            strokeWidth: zone.isFree ? 2 : 3,
          ));
        }
      }
      return out;
    },
    orElse: () => const [],
  );
});

// Parsea una geometría GeoJSON (Polygon | MultiPolygon). Las coordenadas van
// como [lng, lat]; MapPoint es (lat, lng).
List<_Ring> _parseGeometry(String json) {
  if (json.isEmpty) return const [];
  try {
    final g = jsonDecode(json) as Map<String, dynamic>;
    final coords = g['coordinates'] as List;

    List<MapPoint> toRing(List r) => [
          for (final c in r)
            MapPoint((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        ];
    _Ring toPolygon(List rings) {
      final parsed = [for (final r in rings) toRing(r as List)];
      return (outer: parsed.first, holes: parsed.skip(1).toList());
    }

    switch (g['type']) {
      case 'Polygon':
        if (coords.isEmpty) return const [];
        return [toPolygon(coords)];
      case 'MultiPolygon':
        return [
          for (final poly in coords)
            if ((poly as List).isNotEmpty) toPolygon(poly),
        ];
    }
  } catch (_) {/* geometría inválida */}
  return const [];
}

// Color del territorio. Los libres (sin dueño, caso raro) usan el acento; los
// tomados, el color del tipo de dueño.
Color _zoneColor(ZoneModel zone) {
  if (zone.isFree) return AppColors.accent;
  if (zone.isExpiring) return AppColors.zoneExpiring;
  if (zone.ownerType == OwnerType.club) return AppColors.zoneClub;
  return AppColors.zoneOwned;
}
