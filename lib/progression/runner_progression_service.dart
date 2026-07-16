import 'achievement.dart';
import 'achievement_engine.dart';
import 'challenge_experience_calculator.dart';
import 'progression_config.dart';
import 'runner_level_calculator.dart';
import 'runner_progress.dart';
import 'runner_star_calculator.dart';

/// Orquesta la progresión: concede XP por retos (una sola vez), recalcula nivel
/// y estrellas, evalúa logros y produce un resumen de celebración agrupado.
///
/// Es PURO (opera sobre estado inmutable de entrada → salida): no toca Firebase.
/// La persistencia la hace la capa de repositorio con el resultado.
class RunnerProgressionService {
  const RunnerProgressionService({
    this.levels = const RunnerLevelCalculator(),
    this.stars = const RunnerStarCalculator(),
    this.challengeXp = const ChallengeExperienceCalculator(),
    this.achievements = const AchievementEngine(),
  });

  final RunnerLevelCalculator levels;
  final RunnerStarCalculator stars;
  final ChallengeExperienceCalculator challengeXp;
  final AchievementEngine achievements;

  /// Completa un reto: concede su XP EXACTAMENTE UNA VEZ (idempotente por
  /// [challengeId]), recalcula nivel/estrellas y evalúa logros con [statsAfter].
  ProgressionOutcome completeChallenge({
    required RunnerProgress current,
    required String challengeId,
    required ChallengeDifficulty difficulty,
    ChallengePeriod period = ChallengePeriod.individual,
    required RunnerStats statsAfter,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();

    // Idempotencia: reto ya procesado → no se vuelve a conceder nada.
    if (current.processedChallengeIds.contains(challengeId)) {
      return _skip(current);
    }

    final xp = challengeXp.xpFor(difficulty: difficulty, period: period);
    final before = levels.fromTotalXp(current.totalXp);
    final after = levels.fromTotalXp(current.totalXp + xp);

    final progress = _apply(
      current: current,
      addXp: xp,
      statsAfter: statsAfter,
      before: before,
      after: after,
      now: ts,
      newChallengeId: challengeId,
    );

    return ProgressionOutcome(
      progress: progress.$1,
      applied: true,
      celebration: _celebration(before, after, xp, progress.$2),
    );
  }

  /// Procesa una actividad de Strava para evaluar logros SIN duplicar
  /// (idempotente por [activityId]). No concede XP (la XP es de los retos).
  ProgressionOutcome syncStravaActivity({
    required RunnerProgress current,
    required String activityId,
    required RunnerStats statsAfter,
    DateTime? now,
  }) {
    final ts = now ?? DateTime.now();

    if (current.processedActivityIds.contains(activityId)) {
      return _skip(current);
    }

    final level = levels.fromTotalXp(current.totalXp);
    final progress = _apply(
      current: current,
      addXp: 0,
      statsAfter: statsAfter,
      before: level,
      after: level,
      now: ts,
      newActivityId: activityId,
    );

    return ProgressionOutcome(
      progress: progress.$1,
      applied: true,
      celebration: _celebration(level, level, 0, progress.$2),
    );
  }

  // ── Internos ────────────────────────────────────────────────────────────────

  ProgressionOutcome _skip(RunnerProgress current) {
    final level = levels.fromTotalXp(current.totalXp);
    final star = stars.forLevel(level.level);
    return ProgressionOutcome(
      progress: current,
      applied: false,
      celebration: CelebrationSummary(
        xpGained: 0,
        leveledUp: false,
        fromLevel: level.level,
        toLevel: level.level,
        fromStar: star,
        toStar: star,
        newAchievements: const [],
      ),
    );
  }

  // Devuelve (nuevo progreso, logros recién desbloqueados).
  (RunnerProgress, List<Achievement>) _apply({
    required RunnerProgress current,
    required int addXp,
    required RunnerStats statsAfter,
    required RunnerLevel before,
    required RunnerLevel after,
    required DateTime now,
    String? newChallengeId,
    String? newActivityId,
  }) {
    final newAchievements =
        achievements.newlyUnlocked(statsAfter, current.unlockedAchievementIds);

    final unlockDates = {...current.achievementUnlockDates};
    for (final a in newAchievements) {
      unlockDates[a.id] = now;
    }

    final history = [...current.levelHistory];
    for (var l = before.level + 1; l <= after.level; l++) {
      history.add(LevelUpEvent(level: l, at: now));
    }

    final progress = current.copyWith(
      totalXp: current.totalXp + addXp,
      achievementUnlockDates: unlockDates,
      levelHistory: history,
      processedChallengeIds: newChallengeId == null
          ? null
          : {...current.processedChallengeIds, newChallengeId},
      processedActivityIds: newActivityId == null
          ? null
          : {...current.processedActivityIds, newActivityId},
    );

    return (progress, newAchievements);
  }

  CelebrationSummary _celebration(
    RunnerLevel before,
    RunnerLevel after,
    int xp,
    List<Achievement> newAchievements,
  ) {
    return CelebrationSummary(
      xpGained: xp,
      leveledUp: after.level > before.level,
      fromLevel: before.level,
      toLevel: after.level,
      fromStar: stars.forLevel(before.level),
      toStar: stars.forLevel(after.level),
      newAchievements: newAchievements,
    );
  }
}
