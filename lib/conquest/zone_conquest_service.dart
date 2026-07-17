import 'zone_conquest.dart';

class ConquestResult {
  const ConquestResult(this.conquest, {required this.isNew});
  final ZoneConquest conquest;
  final bool isNew; // false si esa actividad ya había conquistado (idempotente)
}

/// Construye el hito de conquista de forma idempotente por (userId, activityId).
/// Puro: no toca Firebase. La persistencia usa el id determinista, así que
/// re-guardar no duplica.
class ZoneConquestService {
  const ZoneConquestService();

  ConquestResult record({
    required String userId,
    required String activityId,
    String? zoneId,
    String zoneName = '',
    String city = '',
    double distanceMeters = 0,
    int durationSeconds = 0,
    double paceMinPerKm = 0,
    double elevationMeters = 0,
    double areaM2 = 0,
    DateTime? now,
    ZoneConquest? existing,
  }) {
    if (existing != null && !existing.isDeleted) {
      return ConquestResult(existing, isNew: false);
    }
    final ts = now ?? DateTime.now();
    return ConquestResult(
      ZoneConquest(
        id: ZoneConquest.idFor(userId, activityId),
        userId: userId,
        activityId: activityId,
        zoneId: zoneId,
        createdAt: ts,
        zoneNameSnapshot: zoneName,
        city: city,
        distanceSnapshot: distanceMeters,
        durationSnapshot: durationSeconds,
        paceSnapshot: paceMinPerKm,
        elevationSnapshot: elevationMeters,
        areaM2Snapshot: areaM2,
      ),
      isNew: true,
    );
  }
}
