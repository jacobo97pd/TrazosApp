/// Entrada mínima por zapatilla para agregar estadísticas.
class ShoeStatEntry {
  const ShoeStatEntry({
    required this.brand,
    required this.model,
    required this.km,
    required this.activities,
  });
  final String brand; // '' si desconocida
  final String model;
  final double km;
  final int activities;
}

class AggregatedShoeStats {
  const AggregatedShoeStats({
    required this.kmByBrand,
    required this.kmByModel,
    required this.activitiesByBrand,
  });
  final Map<String, double> kmByBrand;
  final Map<String, double> kmByModel;
  final Map<String, int> activitiesByBrand;

  // Aviso para evitar conclusiones causales incorrectas (mejor ritmo ≠ mejor
  // marca). La UI debe mostrarlo junto a las comparativas.
  static const causalityNote =
      'Estos datos reflejan tu uso, no el rendimiento de una marca. '
      'Un mejor ritmo medio no implica que una marca sea mejor.';
}

/// Agrega kilómetros/actividades por marca y modelo. Puro.
class ShoeStatsAggregator {
  const ShoeStatsAggregator();

  AggregatedShoeStats aggregate(Iterable<ShoeStatEntry> shoes) {
    final kmBrand = <String, double>{};
    final kmModel = <String, double>{};
    final actBrand = <String, int>{};
    for (final s in shoes) {
      final brand = s.brand.trim().isEmpty ? 'Sin marca' : s.brand.trim();
      final model = s.model.trim().isEmpty ? brand : '$brand ${s.model.trim()}';
      final km = (s.km.isNaN || s.km.isInfinite || s.km < 0) ? 0.0 : s.km;
      kmBrand[brand] = (kmBrand[brand] ?? 0) + km;
      kmModel[model] = (kmModel[model] ?? 0) + km;
      actBrand[brand] = (actBrand[brand] ?? 0) + s.activities;
    }
    return AggregatedShoeStats(
      kmByBrand: kmBrand,
      kmByModel: kmModel,
      activitiesByBrand: actBrand,
    );
  }
}
