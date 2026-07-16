import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/social/runner_connection.dart';
import 'package:runrace/social/runner_connection_service.dart';

void main() {
  const svc = RunnerConnectionService();
  final t = DateTime(2026, 1, 1);

  test('id determinista independiente del orden', () {
    expect(RunnerConnection.idFor('a', 'b'), RunnerConnection.idFor('b', 'a'));
  });

  test('solicitud nueva → pending', () {
    final out = svc.request(
        requester: 'a',
        recipient: 'b',
        source: ConnectionSource.username,
        now: t);
    expect(out.changed, isTrue);
    expect(out.connection!.status, ConnectionStatus.pending);
    expect(out.connection!.requesterUserId, 'a');
    expect(out.connection!.participants, ['a', 'b']);
  });

  test('no puedes conectarte contigo mismo', () {
    final out = svc.request(
        requester: 'a', recipient: 'a', source: ConnectionSource.username);
    expect(out.changed, isFalse);
    expect(out.reason, 'self');
  });

  test('solicitud DUPLICADA del mismo solicitante no reenvía', () {
    final first = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    final dup = svc.request(
        current: first,
        requester: 'a',
        recipient: 'b',
        source: ConnectionSource.username);
    expect(dup.changed, isFalse);
    expect(dup.reason, 'duplicate');
  });

  test('solicitud CRUZADA (b pide con a ya pendiente) → aceptada', () {
    final first = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    final crossed = svc.request(
        current: first,
        requester: 'b',
        recipient: 'a',
        source: ConnectionSource.username);
    expect(crossed.connection!.status, ConnectionStatus.accepted);
  });

  test('solo el destinatario acepta (nadie en nombre de otro)', () {
    final pending = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    final byRequester = svc.accept(current: pending, actor: 'a');
    expect(byRequester.changed, isFalse);
    final byRecipient = svc.accept(current: pending, actor: 'b', now: t);
    expect(byRecipient.connection!.status, ConnectionStatus.accepted);
  });

  test('no se puede solicitar sobre una relación bloqueada', () {
    final pending = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    final blocked = svc.block(current: pending, actor: 'b', now: t).connection!;
    final retry = svc.request(
        current: blocked,
        requester: 'a',
        recipient: 'b',
        source: ConnectionSource.username);
    expect(retry.changed, isFalse);
    expect(retry.reason, 'blocked');
  });

  test('ya conectados → nueva solicitud es no-op', () {
    var c = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    c = svc.accept(current: c, actor: 'b', now: t).connection!;
    final again = svc.request(
        current: c,
        requester: 'a',
        recipient: 'b',
        source: ConnectionSource.username);
    expect(again.reason, 'already');
  });

  test('tras declinar se puede volver a solicitar', () {
    var c = svc
        .request(
            requester: 'a',
            recipient: 'b',
            source: ConnectionSource.username,
            now: t)
        .connection!;
    c = svc.decline(current: c, actor: 'b', now: t).connection!;
    final again = svc.request(
        current: c,
        requester: 'b',
        recipient: 'a',
        source: ConnectionSource.qr,
        now: t);
    expect(again.connection!.status, ConnectionStatus.pending);
    expect(again.connection!.requesterUserId, 'b');
  });
}
