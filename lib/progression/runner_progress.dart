import 'achievement.dart';
import 'runner_star_calculator.dart';

/// Subida de nivel registrada (para el historial).
class LevelUpEvent {
  const LevelUpEvent({required this.level, required this.at});
  final int level;
  final DateTime at;
}

/// Estado persistido de la progresión de un corredor. Inmutable.
/// Contiene los conjuntos de idempotencia (retos y actividades ya procesados)
/// para que nada se conceda dos veces.
class RunnerProgress {
  const RunnerProgress({
    this.totalXp = 0,
    this.achievementUnlockDates = const {},
    this.processedChallengeIds = const {},
    this.processedActivityIds = const {},
    this.levelHistory = const [],
  });

  final int totalXp;

  /// id de logro → fecha de desbloqueo (permanente).
  final Map<String, DateTime> achievementUnlockDates;

  /// Retos ya procesados (idempotencia de XP).
  final Set<String> processedChallengeIds;

  /// Actividades de Strava ya procesadas (idempotencia de logros/progreso).
  final Set<String> processedActivityIds;

  final List<LevelUpEvent> levelHistory;

  Set<String> get unlockedAchievementIds => achievementUnlockDates.keys.toSet();

  RunnerProgress copyWith({
    int? totalXp,
    Map<String, DateTime>? achievementUnlockDates,
    Set<String>? processedChallengeIds,
    Set<String>? processedActivityIds,
    List<LevelUpEvent>? levelHistory,
  }) =>
      RunnerProgress(
        totalXp: totalXp ?? this.totalXp,
        achievementUnlockDates:
            achievementUnlockDates ?? this.achievementUnlockDates,
        processedChallengeIds:
            processedChallengeIds ?? this.processedChallengeIds,
        processedActivityIds: processedActivityIds ?? this.processedActivityIds,
        levelHistory: levelHistory ?? this.levelHistory,
      );
}

/// Resumen AGRUPADO de una concesión de progresión, para una única celebración
/// (evita diálogos consecutivos).
class CelebrationSummary {
  const CelebrationSummary({
    required this.xpGained,
    required this.leveledUp,
    required this.fromLevel,
    required this.toLevel,
    required this.fromStar,
    required this.toStar,
    required this.newAchievements,
  });

  final int xpGained;
  final bool leveledUp;
  final int fromLevel;
  final int toLevel;
  final RunnerStar fromStar;
  final RunnerStar toStar;
  final List<Achievement> newAchievements;

  bool get starChanged => fromStar.stars != toStar.stars;
  bool get hasSomething =>
      xpGained > 0 || leveledUp || newAchievements.isNotEmpty;
}

/// Resultado de aplicar progresión. [applied] es false si la operación era
/// idempotente (ya se había procesado ese reto/actividad).
class ProgressionOutcome {
  const ProgressionOutcome({
    required this.progress,
    required this.applied,
    required this.celebration,
  });

  final RunnerProgress progress;
  final bool applied;
  final CelebrationSummary celebration;
}
