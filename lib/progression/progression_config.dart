// Configuración CENTRAL del sistema de progresión (XP, niveles, estrellas).
// Todos los números viven aquí para evitar valores mágicos por el código.
// La progresión es reconocimiento deportivo: NO hay monedas, skins ni economía.

/// Dificultad de un reto → XP base.
enum ChallengeDifficulty { veryEasy, easy, medium, hard, legendary }

/// Tipo/periodo del reto → multiplicador de XP.
enum ChallengePeriod { individual, weekly, monthly, special }

/// Escalón de estrellas del corredor (categoría global).
class StarTier {
  const StarTier({
    required this.minLevel,
    required this.stars,
    required this.label,
  });

  final int minLevel; // nivel a partir del cual aplica este escalón
  final int stars; // 1..5
  final String label; // Principiante, Constante, …
}

abstract final class ProgressionConfig {
  // ── XP por reto ────────────────────────────────────────────────────────────
  // Valores orientativos y ajustables.
  static const Map<ChallengeDifficulty, int> xpByDifficulty = {
    ChallengeDifficulty.veryEasy: 25,
    ChallengeDifficulty.easy: 50,
    ChallengeDifficulty.medium: 100,
    ChallengeDifficulty.hard: 200,
    ChallengeDifficulty.legendary: 500,
  };

  // Multiplicador según el tipo de reto (individual, semanal, mensual, especial).
  static const Map<ChallengePeriod, double> periodMultiplier = {
    ChallengePeriod.individual: 1.0,
    ChallengePeriod.weekly: 1.2,
    ChallengePeriod.monthly: 1.5,
    ChallengePeriod.special: 2.0,
  };

  // ── Curva de nivel ──────────────────────────────────────────────────────────
  // XP para pasar del nivel L al L+1 = base + (L-1)*growth. Es progresiva (cada
  // nivel cuesta más) pero no demasiado lenta. Ajustable.
  static const int baseLevelIncrement = 100;
  static const int levelIncrementGrowth = 50;

  /// Tope de seguridad para el bucle de cálculo de nivel.
  static const int maxLevel = 999;

  // ── Estrellas del corredor ──────────────────────────────────────────────────
  // Deben ir ordenadas por minLevel ascendente.
  static const List<StarTier> starTiers = [
    StarTier(minLevel: 1, stars: 1, label: 'Principiante'),
    StarTier(minLevel: 6, stars: 2, label: 'Constante'),
    StarTier(minLevel: 16, stars: 3, label: 'Experimentado'),
    StarTier(minLevel: 31, stars: 4, label: 'Avanzado'),
    StarTier(minLevel: 51, stars: 5, label: 'Élite'),
  ];
}
