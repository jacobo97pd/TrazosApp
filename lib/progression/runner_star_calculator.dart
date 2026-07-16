import 'progression_config.dart';

/// Categoría global del corredor (1..5 estrellas) con su etiqueta.
class RunnerStar {
  const RunnerStar({required this.stars, required this.label});

  final int stars; // 1..5
  final String label; // Principiante … Élite

  @override
  bool operator ==(Object other) =>
      other is RunnerStar && other.stars == stars && other.label == label;

  @override
  int get hashCode => Object.hash(stars, label);

  @override
  String toString() => 'RunnerStar($stars★ $label)';
}

/// Traduce el nivel del corredor a su escalón de estrellas.
/// Puro y testeable; los rangos vienen de la config (ajustables).
class RunnerStarCalculator {
  const RunnerStarCalculator({this.tiers = ProgressionConfig.starTiers});

  final List<StarTier> tiers;

  RunnerStar forLevel(int level) {
    var current = tiers.first;
    for (final tier in tiers) {
      if (level >= tier.minLevel) {
        current = tier;
      } else {
        break; // tiers está ordenado ascendente por minLevel
      }
    }
    return RunnerStar(stars: current.stars, label: current.label);
  }
}
