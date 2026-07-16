import 'running_shoe.dart';
import 'shoe_activity_link.dart';
import 'shoe_distance_calculator.dart';
import 'shoe_name_parser.dart';
import 'strava_gear.dart';

/// Cambios a persistir tras una sincronización.
class ShoeSyncPlan {
  const ShoeSyncPlan(this.shoes, this.links);
  final List<RunningShoe> shoes; // a crear/actualizar
  final List<ShoeActivityLink> links; // a crear/actualizar
}

/// Calcula (puro) el plan de sincronización: crea zapatillas nuevas desde el
/// equipamiento de Strava, enlaza actividades↔zapatilla de forma idempotente y
/// recalcula el kilometraje. NO sobrescribe campos editados por el usuario
/// (marca/modelo/apodo de zapatillas ya existentes).
class ShoeSyncService {
  const ShoeSyncService({
    this.parser = const ShoeNameParser(),
    this.calc = const ShoeDistanceCalculator(),
  });
  final ShoeNameParser parser;
  final ShoeDistanceCalculator calc;

  static String shoeIdFor(String gearId) => 'strava_$gearId';

  ShoeSyncPlan plan({
    required String userId,
    required List<StravaGear> gears,
    required List<StravaRunActivity> activities,
    required List<RunningShoe> existingShoes,
    required List<ShoeActivityLink> existingLinks,
    required DateTime now,
  }) {
    final byId = {for (final s in existingShoes) s.id: s};

    // 1) Zapatillas: crear las nuevas; a las existentes solo tocar sync/fecha.
    final shoesOut = <RunningShoe>[];
    for (final g in gears) {
      final id = shoeIdFor(g.id);
      final existing = byId[id];
      if (existing == null) {
        final p = parser.parse(g.name);
        shoesOut.add(RunningShoe(
          id: id,
          userId: userId,
          source: ShoeSource.strava,
          stravaGearId: g.id,
          brand: p.brand,
          model: p.model,
          nickname: p.nickname,
          createdAt: now,
          updatedAt: now,
          lastSyncedAt: now,
        ));
      }
    }

    // 2) Enlaces: uno por actividad (idempotente). Con gear → zapatilla local;
    //    sin gear → 'unassigned' (aparece en "sin zapatilla").
    final linksById = {for (final l in existingLinks) l.id: l};
    for (final a in activities) {
      final shoeId = a.gearId == null ? 'unassigned' : shoeIdFor(a.gearId!);
      final id = ShoeActivityLink.idFor(userId, a.id);
      final prev = linksById[id];
      // Respeta una reasignación manual del usuario a una zapatilla concreta.
      final keepManual = prev != null &&
          prev.source == 'manual' &&
          prev.shoeId != 'unassigned';
      final link = ShoeActivityLink(
        userId: userId,
        activityId: a.id,
        shoeId: keepManual ? prev.shoeId : shoeId,
        distanceMeters: a.distanceMeters,
        source: keepManual ? 'manual' : 'strava',
      );
      linksById[id] = link;
    }

    // 3) Recalcular km sincronizados de cada zapatilla (existentes + nuevas).
    final allShoes = [...existingShoes, ...shoesOut];
    final allLinks = linksById.values.toList();
    final recomputed = <RunningShoe>[];
    for (final s in allShoes) {
      final synced = calc.syncedMetersFor(s.id, allLinks);
      if (s.syncedDistanceMeters != synced ||
          shoesOut.any((n) => n.id == s.id)) {
        recomputed.add(s.copyWith(
          syncedDistanceMeters: synced,
          lastSyncedAt: now,
          updatedAt: now,
        ));
      }
    }

    return ShoeSyncPlan(recomputed, linksById.values.toList());
  }
}
