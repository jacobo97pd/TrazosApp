/// Enlace actividad ↔ zapatilla. Es la FUENTE DE VERDAD del kilometraje
/// sincronizado: un doc por actividad (id determinista) → nunca suma dos veces
/// y permite reconstruir los km al eliminar/actualizar actividades o cambiar la
/// zapatilla asignada.
class ShoeActivityLink {
  const ShoeActivityLink({
    required this.userId,
    required this.activityId,
    required this.shoeId,
    required this.distanceMeters,
    required this.source,
  });

  final String userId;
  final String activityId;
  final String shoeId; // '' o 'unassigned' = sin zapatilla
  final double distanceMeters;
  final String source; // 'strava' | 'manual'

  /// id estable por usuario+actividad (idempotencia).
  String get id => idFor(userId, activityId);
  static String idFor(String userId, String activityId) =>
      '${userId}_$activityId';

  bool get assigned => shoeId.isNotEmpty && shoeId != 'unassigned';

  ShoeActivityLink copyWith({String? shoeId, double? distanceMeters}) =>
      ShoeActivityLink(
        userId: userId,
        activityId: activityId,
        shoeId: shoeId ?? this.shoeId,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        source: source,
      );
}
