/// Visibilidad de una publicación/conquista. Nunca pública por defecto.
enum ConquestVisibility { onlyMe, connections, group, public }

/// Modo de privacidad de ubicación en el contenido.
enum LocationPrivacyMode { fullZone, neighborhood, city, none }

/// Hito PERMANENTE: el usuario conquistó una zona. Guarda snapshots para que una
/// actualización posterior de la actividad no altere el recuerdo original.
class ZoneConquest {
  const ZoneConquest({
    required this.id,
    required this.userId,
    required this.activityId,
    this.zoneId,
    required this.createdAt,
    this.zoneNameSnapshot = '',
    this.city = '',
    this.distanceSnapshot = 0,
    this.durationSnapshot = 0,
    this.paceSnapshot = 0,
    this.elevationSnapshot = 0,
    this.areaM2Snapshot = 0,
    this.isDeleted = false,
  });

  final String id;
  final String userId;
  final String
      activityId; // run/actividad que la originó (clave de idempotencia)
  final String? zoneId;
  final DateTime createdAt;

  // Snapshots inmutables del momento de la conquista.
  final String zoneNameSnapshot;
  final String city;
  final double distanceSnapshot; // metros
  final int durationSnapshot; // segundos
  final double paceSnapshot; // min/km
  final double elevationSnapshot;
  final double areaM2Snapshot;

  final bool isDeleted;

  /// Clave determinista: una actividad conquista una zona una sola vez.
  static String idFor(String userId, String activityId) =>
      'conq_${userId}_$activityId';
}
