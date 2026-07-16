import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/progression_config.dart';
import 'package:runrace/social/private_challenge.dart';
import 'package:runrace/social/private_challenge_service.dart';

void main() {
  const svc = PrivateChallengeService();
  final start = DateTime(2026, 1, 1);
  final end = DateTime(2026, 1, 8);

  PrivateChallenge make({
    ChallengeModality modality = ChallengeModality.oneVsOne,
    num target = 0,
    Set<String> invited = const {'b'},
  }) =>
      svc.create(
        id: 'pc1',
        creator: 'a',
        invited: invited,
        modality: modality,
        metric: PrivateChallengeMetric.distanceKm,
        difficulty: ChallengeDifficulty.medium,
        period: ChallengePeriod.weekly,
        startAt: start,
        endAt: end,
        target: target,
      );

  test('crear con invitados → invited y creador participa', () {
    final c = make();
    expect(c.status, PrivateChallengeStatus.invited);
    expect(c.accepted, {'a'});
    expect(c.invited, {'b'});
    expect(c.participants, {'a', 'b'});
  });

  test('aceptar requiere estar invitado; activa con 2', () {
    var c = make();
    c = svc.accept(c, 'x'); // no invitado → sin efecto
    expect(c.status, PrivateChallengeStatus.invited);
    c = svc.accept(c, 'b');
    expect(c.status, PrivateChallengeStatus.active);
    expect(c.accepted, {'a', 'b'});
  });

  test('progreso solo de participantes y con reto activo', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'x', 10); // no participa
    expect(c.progressByUser['x'], isNull);
    c = svc.updateProgress(c, 'b', 12);
    expect(c.progressByUser['b'], 12);
  });

  test('progreso ABSOLUTO es idempotente', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'b', 12);
    c = svc.updateProgress(c, 'b', 12); // mismo valor
    expect(c.progressByUser['b'], 12);
    expect(c.groupProgress, 12);
  });

  test('competitivo: gana el de mayor progreso al expirar', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'a', 20);
    c = svc.updateProgress(c, 'b', 12);
    c = svc.evaluate(c, end);
    expect(c.status, PrivateChallengeStatus.completed);
    expect(c.winners(), ['a']);
  });

  test('empate: se muestran ambos', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'a', 15);
    c = svc.updateProgress(c, 'b', 15);
    c = svc.evaluate(c, end);
    expect(c.winners().toSet(), {'a', 'b'});
  });

  test('coop: completed solo si el grupo llega al objetivo', () {
    var c = svc.accept(make(modality: ChallengeModality.coop, target: 30), 'b');
    c = svc.updateProgress(c, 'a', 10);
    c = svc.updateProgress(c, 'b', 12); // 22 < 30
    final expired = svc.evaluate(c, end);
    expect(expired.status, PrivateChallengeStatus.expired);

    c = svc.updateProgress(c, 'b', 25); // 35 >= 30
    final done = svc.evaluate(c, end);
    expect(done.status, PrivateChallengeStatus.completed);
    expect(done.pendingRewards().toSet(), {'a', 'b'});
  });

  test('no expira antes de tiempo', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'a', 5);
    c = svc.evaluate(c, start); // aún no
    expect(c.status, PrivateChallengeStatus.active);
  });

  test('recompensa idempotente (markRewarded)', () {
    var c = svc.accept(make(), 'b');
    c = svc.updateProgress(c, 'a', 20);
    c = svc.evaluate(c, end);
    expect(c.pendingRewards(), ['a']);
    c = svc.markRewarded(c, ['a']);
    expect(c.pendingRewards(), isEmpty); // ya no se vuelve a recompensar
  });

  test('solo el creador cancela', () {
    var c = make();
    c = svc.cancel(c, 'b'); // no creador
    expect(c.status, PrivateChallengeStatus.invited);
    c = svc.cancel(c, 'a');
    expect(c.status, PrivateChallengeStatus.cancelled);
  });
}
