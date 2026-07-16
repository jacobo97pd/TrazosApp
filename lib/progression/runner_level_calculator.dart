import 'progression_config.dart';

/// Estado de nivel derivado de la XP total. Inmutable.
class RunnerLevel {
  const RunnerLevel({
    required this.level,
    required this.totalXp,
    required this.xpIntoLevel,
    required this.xpForLevel,
    required this.xpToNextLevel,
  });

  /// Nivel actual (empieza en 1).
  final int level;

  /// Experiencia total acumulada.
  final int totalXp;

  /// XP acumulada DENTRO del nivel actual.
  final int xpIntoLevel;

  /// XP total que exige el nivel actual para subir al siguiente.
  final int xpForLevel;

  /// XP que falta para el siguiente nivel.
  final int xpToNextLevel;

  /// Progreso dentro del nivel [0, 1].
  double get progress =>
      xpForLevel == 0 ? 1.0 : (xpIntoLevel / xpForLevel).clamp(0.0, 1.0);

  @override
  String toString() =>
      'RunnerLevel(level: $level, totalXp: $totalXp, into: $xpIntoLevel/$xpForLevel)';
}

/// Convierte XP total ⇆ nivel con una curva no lineal y progresiva.
/// Puro y testeable: no depende de Firebase ni de estado externo.
class RunnerLevelCalculator {
  const RunnerLevelCalculator({
    this.baseIncrement = ProgressionConfig.baseLevelIncrement,
    this.incrementGrowth = ProgressionConfig.levelIncrementGrowth,
    this.maxLevel = ProgressionConfig.maxLevel,
  });

  final int baseIncrement;
  final int incrementGrowth;
  final int maxLevel;

  /// XP necesaria para pasar del nivel [level] al siguiente.
  int incrementForLevel(int level) =>
      baseIncrement + (level - 1) * incrementGrowth;

  /// XP total acumulada necesaria para ALCANZAR el inicio de [level].
  int totalXpForLevel(int level) {
    var xp = 0;
    for (var l = 1; l < level; l++) {
      xp += incrementForLevel(l);
    }
    return xp;
  }

  /// Deriva el estado de nivel a partir de la XP total.
  RunnerLevel fromTotalXp(int totalXp) {
    final xp = totalXp < 0 ? 0 : totalXp;

    var level = 1;
    var cumulative = 0;
    while (level < maxLevel) {
      final inc = incrementForLevel(level);
      if (cumulative + inc > xp) break;
      cumulative += inc;
      level++;
    }

    final inc = incrementForLevel(level);
    final into = xp - cumulative;
    return RunnerLevel(
      level: level,
      totalXp: xp,
      xpIntoLevel: into,
      xpForLevel: inc,
      xpToNextLevel: inc - into,
    );
  }
}
