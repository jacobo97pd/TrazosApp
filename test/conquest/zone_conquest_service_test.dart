import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/zone_conquest.dart';
import 'package:runrace/conquest/zone_conquest_service.dart';
import 'package:runrace/progression/achievement.dart';
import 'package:runrace/progression/achievement_engine.dart';

void main() {
  const svc = ZoneConquestService();
  final now = DateTime(2026, 1, 1);

  test('id determinista por (usuario, actividad)', () {
    expect(ZoneConquest.idFor('u', 'a1'), 'conq_u_a1');
  });

  test('conquista nueva guarda snapshots', () {
    final r = svc.record(
      userId: 'u',
      activityId: 'a1',
      distanceMeters: 5200,
      durationSeconds: 1800,
      paceMinPerKm: 5.7,
      areaM2: 12000,
      city: 'Madrid',
      now: now,
    );
    expect(r.isNew, isTrue);
    expect(r.conquest.id, 'conq_u_a1');
    expect(r.conquest.distanceSnapshot, 5200);
    expect(r.conquest.areaM2Snapshot, 12000);
    expect(r.conquest.city, 'Madrid');
  });

  test('IDEMPOTENTE: misma actividad no conquista dos veces', () {
    final first = svc.record(userId: 'u', activityId: 'a1', now: now).conquest;
    final again = svc.record(
      userId: 'u',
      activityId: 'a1',
      now: DateTime(2026, 2, 1),
      existing: first,
    );
    expect(again.isNew, isFalse);
    expect(again.conquest.createdAt, now); // conserva el original
  });

  test('una conquista borrada puede rehacerse', () {
    final deleted = ZoneConquest(
      id: ZoneConquest.idFor('u', 'a1'),
      userId: 'u',
      activityId: 'a1',
      createdAt: now,
      isDeleted: true,
    );
    final r =
        svc.record(userId: 'u', activityId: 'a1', existing: deleted, now: now);
    expect(r.isNew, isTrue);
  });

  test('logros de conquista se desbloquean una sola vez', () {
    const engine = AchievementEngine();
    final first = engine.newlyUnlocked(
        const RunnerStats(zonesConquered: 1), {}).map((a) => a.id);
    expect(first, contains('conquest.first'));
    // Ya desbloqueado → no reaparece.
    final again = engine.newlyUnlocked(
        const RunnerStats(zonesConquered: 2), {'conquest.first'});
    expect(again.map((a) => a.id), isNot(contains('conquest.first')));
    expect(again.map((a) => a.id), isNot(contains('conquest.ten')));
  });
}
