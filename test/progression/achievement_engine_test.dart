import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/achievement.dart';
import 'package:runrace/progression/achievement_engine.dart';

void main() {
  const engine = AchievementEngine();

  test('desbloquea logros cuyo criterio se cumple', () {
    const stats = RunnerStats(totalKm: 1);
    final unlocked = engine.newlyUnlocked(stats, {});
    expect(unlocked.map((a) => a.id), contains('distance.first_km'));
  });

  test('no concede dos veces un logro ya desbloqueado', () {
    const stats = RunnerStats(totalKm: 1);
    final unlocked = engine.newlyUnlocked(stats, {'distance.first_km'});
    expect(unlocked.map((a) => a.id), isNot(contains('distance.first_km')));
  });

  test('longestRunKm distingue media maratón de maratón', () {
    // 25 km: media maratón sí, maratón no.
    final unlocked = engine.newlyUnlocked(const RunnerStats(longestRunKm: 25), {});
    final ids = unlocked.map((a) => a.id);
    expect(ids, contains('distance.half_marathon'));
    expect(ids, isNot(contains('distance.marathon')));
  });

  test('progreso parcial de un logro (evaluate)', () {
    final statuses = engine.evaluate(const RunnerStats(totalKm: 50));
    final km100 = statuses.firstWhere((s) => s.achievement.id == 'distance.km_100');
    expect(km100.unlocked, isFalse);
    expect(km100.criterionMet, isFalse);
    expect(km100.progress, closeTo(0.5, 1e-9));
  });

  test('evaluate respeta las fechas de desbloqueo persistidas', () {
    final when = DateTime(2026, 1, 1);
    final statuses = engine.evaluate(
      const RunnerStats(totalKm: 1),
      unlockedAt: {'distance.first_km': when},
    );
    final first =
        statuses.firstWhere((s) => s.achievement.id == 'distance.first_km');
    expect(first.unlocked, isTrue);
    expect(first.unlockedAt, when);
  });

  test('todos los ids del catálogo son únicos', () {
    final ids = engine.catalog.map((a) => a.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
