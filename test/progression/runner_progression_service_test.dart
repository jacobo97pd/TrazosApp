import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/achievement.dart';
import 'package:runrace/progression/progression_config.dart';
import 'package:runrace/progression/runner_progress.dart';
import 'package:runrace/progression/runner_progression_service.dart';

void main() {
  const service = RunnerProgressionService();
  const noStats = RunnerStats();

  test('concede XP de un reto y recalcula nivel', () {
    const start = RunnerProgress();
    final out = service.completeChallenge(
      current: start,
      challengeId: 'c1',
      difficulty: ChallengeDifficulty.medium,
      statsAfter: noStats,
    );
    expect(out.applied, isTrue);
    expect(out.progress.totalXp, 100);
    expect(out.celebration.xpGained, 100);
    expect(out.progress.processedChallengeIds, contains('c1'));
  });

  test('IDEMPOTENTE: el mismo reto no concede XP dos veces', () {
    const start = RunnerProgress();
    final first = service.completeChallenge(
      current: start,
      challengeId: 'c1',
      difficulty: ChallengeDifficulty.medium,
      statsAfter: noStats,
    );
    final second = service.completeChallenge(
      current: first.progress,
      challengeId: 'c1',
      difficulty: ChallengeDifficulty.medium,
      statsAfter: noStats,
    );
    expect(second.applied, isFalse);
    expect(second.progress.totalXp, 100); // sin cambios
    expect(second.celebration.xpGained, 0);
  });

  test('varios niveles con un solo reto (legendario especial = 1000 XP)', () {
    const start = RunnerProgress(); // nivel 1
    final out = service.completeChallenge(
      current: start,
      challengeId: 'boss',
      difficulty: ChallengeDifficulty.legendary,
      period: ChallengePeriod.special,
      statsAfter: noStats,
    );
    expect(out.progress.totalXp, 1000);
    expect(out.celebration.leveledUp, isTrue);
    expect(out.celebration.fromLevel, 1);
    expect(out.celebration.toLevel, 6); // 1000 XP → nivel 6
    // Historial: una entrada por cada nivel ganado (2..6).
    expect(out.progress.levelHistory.map((e) => e.level), [2, 3, 4, 5, 6]);
  });

  test('cambio de estrella al subir de categoría', () {
    // Llega a nivel 6 (2 estrellas) desde nivel 1 (1 estrella).
    const start = RunnerProgress();
    final out = service.completeChallenge(
      current: start,
      challengeId: 'boss',
      difficulty: ChallengeDifficulty.legendary,
      period: ChallengePeriod.special,
      statsAfter: noStats,
    );
    expect(out.celebration.fromStar.stars, 1);
    expect(out.celebration.toStar.stars, 2);
    expect(out.celebration.starChanged, isTrue);
  });

  test('completar un reto desbloquea logros (celebración agrupada)', () {
    const start = RunnerProgress();
    final out = service.completeChallenge(
      current: start,
      challengeId: 'c1',
      difficulty: ChallengeDifficulty.medium,
      statsAfter: const RunnerStats(challengesCompleted: 1, totalKm: 1),
    );
    final ids = out.celebration.newAchievements.map((a) => a.id);
    expect(ids, contains('challenges.first'));
    expect(ids, contains('distance.first_km'));
    // XP + subida + logros van en UN solo resumen.
    expect(out.celebration.hasSomething, isTrue);
  });

  test('Strava: procesar la misma actividad no duplica progreso', () {
    const start = RunnerProgress();
    final first = service.syncStravaActivity(
      current: start,
      activityId: 'act-42',
      statsAfter: const RunnerStats(stravaImports: 1),
    );
    expect(first.applied, isTrue);
    expect(first.celebration.newAchievements.map((a) => a.id),
        contains('strava.first_import'));

    // Reprocesar la MISMA actividad (p. ej. re-sync o actividad editada).
    final again = service.syncStravaActivity(
      current: first.progress,
      activityId: 'act-42',
      statsAfter: const RunnerStats(stravaImports: 1),
    );
    expect(again.applied, isFalse);
    expect(again.progress.achievementUnlockDates.length,
        first.progress.achievementUnlockDates.length);
  });

  test('logro ya desbloqueado no se vuelve a conceder en otra actividad', () {
    const start = RunnerProgress();
    final a = service.syncStravaActivity(
      current: start,
      activityId: 'a1',
      statsAfter: const RunnerStats(stravaImports: 1),
    );
    final b = service.syncStravaActivity(
      current: a.progress,
      activityId: 'a2',
      statsAfter: const RunnerStats(stravaImports: 2),
    );
    expect(b.applied, isTrue);
    // strava.first_import ya estaba: no reaparece en b.
    expect(b.celebration.newAchievements.map((a) => a.id),
        isNot(contains('strava.first_import')));
  });

  test('sincronización fuera de orden: cada actividad se aplica una vez', () {
    const start = RunnerProgress();
    final a2 = service.syncStravaActivity(
      current: start,
      activityId: 'a2',
      statsAfter: const RunnerStats(stravaImports: 2),
    );
    final a1 = service.syncStravaActivity(
      current: a2.progress,
      activityId: 'a1',
      statsAfter: const RunnerStats(stravaImports: 2),
    );
    expect(a1.applied, isTrue);
    expect(a1.progress.processedActivityIds, containsAll(['a1', 'a2']));
  });

  test('la fecha de desbloqueo original se conserva', () {
    final t1 = DateTime(2026, 1, 1);
    const start = RunnerProgress();
    final a = service.syncStravaActivity(
      current: start,
      activityId: 'a1',
      statsAfter: const RunnerStats(stravaImports: 1),
      now: t1,
    );
    // Otra actividad más tarde que NO desbloquea nada nuevo del first_import.
    final b = service.syncStravaActivity(
      current: a.progress,
      activityId: 'a2',
      statsAfter: const RunnerStats(stravaImports: 1),
      now: DateTime(2026, 2, 1),
    );
    expect(b.progress.achievementUnlockDates['strava.first_import'], t1);
  });
}
