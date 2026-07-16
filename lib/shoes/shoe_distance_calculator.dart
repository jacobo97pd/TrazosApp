import 'shoe_activity_link.dart';

/// Calcula el kilometraje de forma IDEMPOTENTE y RECONSTRUIBLE a partir de los
/// enlaces actividad↔zapatilla (la fuente de verdad), no de un contador mutable.
/// Así, al eliminar/actualizar una actividad o reasignar zapatilla, basta con
/// recalcular sobre los enlaces actuales.
class ShoeDistanceCalculator {
  const ShoeDistanceCalculator();

  /// Metros sincronizados de una zapatilla (suma de sus enlaces, deduplicados
  /// por actividad por seguridad).
  double syncedMetersFor(String shoeId, Iterable<ShoeActivityLink> links) {
    final seen = <String>{};
    double total = 0;
    for (final l in links) {
      if (l.shoeId != shoeId || !l.assigned) continue;
      if (!seen.add(l.activityId)) continue; // ya contada
      final d = l.distanceMeters;
      if (d.isNaN || d.isInfinite || d < 0) continue; // valores basura fuera
      total += d;
    }
    return total;
  }

  /// Total = inicial declarado + sincronizado + local (manual).
  double totalMetersFor({
    required String shoeId,
    required double initialMeters,
    required double localMeters,
    required Iterable<ShoeActivityLink> links,
  }) {
    final safeInitial = _clean(initialMeters);
    final safeLocal = _clean(localMeters);
    return safeInitial + syncedMetersFor(shoeId, links) + safeLocal;
  }

  double _clean(double v) => (v.isNaN || v.isInfinite || v < 0) ? 0 : v;
}
