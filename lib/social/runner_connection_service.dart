import 'runner_connection.dart';

/// Resultado de una operación sobre una conexión. [changed] es false cuando la
/// operación no aplica (idempotente/impedida) e incluye el [reason].
class ConnectionOutcome {
  const ConnectionOutcome(this.connection, {this.changed = true, this.reason});
  final RunnerConnection? connection;
  final bool changed;
  final String? reason;
}

/// Lógica pura de conexiones. No toca Firebase: recibe el estado actual del par
/// (o null) y devuelve el nuevo estado, con todas las guardas del spec.
class RunnerConnectionService {
  const RunnerConnectionService();

  /// Envía (o resuelve) una solicitud entre [requester] y [recipient].
  ConnectionOutcome request({
    RunnerConnection? current,
    required String requester,
    required String recipient,
    required ConnectionSource source,
    DateTime? now,
  }) {
    if (requester == recipient) {
      return const ConnectionOutcome(null, changed: false, reason: 'self');
    }
    final ts = now ?? DateTime.now();
    final id = RunnerConnection.idFor(requester, recipient);

    if (current == null) {
      return ConnectionOutcome(RunnerConnection(
        id: id,
        requesterUserId: requester,
        recipientUserId: recipient,
        status: ConnectionStatus.pending,
        source: source,
        createdAt: ts,
        updatedAt: ts,
      ));
    }

    switch (current.status) {
      case ConnectionStatus.blocked:
        // No se puede solicitar a un usuario en una relación bloqueada.
        return ConnectionOutcome(current, changed: false, reason: 'blocked');
      case ConnectionStatus.accepted:
        return ConnectionOutcome(current, changed: false, reason: 'already');
      case ConnectionStatus.pending:
        if (current.requesterUserId == requester) {
          // Mismo solicitante → no reenviar (dedup).
          return ConnectionOutcome(current,
              changed: false, reason: 'duplicate');
        }
        // Solicitud cruzada (el otro ya te la había enviado) → se acepta.
        return ConnectionOutcome(current.copyWith(
          status: ConnectionStatus.accepted,
          acceptedAt: ts,
          updatedAt: ts,
        ));
      case ConnectionStatus.suggested:
      case ConnectionStatus.declined:
      case ConnectionStatus.removed:
        // Relación inactiva → nueva solicitud limpia.
        return ConnectionOutcome(current.copyWith(
          requesterUserId: requester,
          recipientUserId: recipient,
          status: ConnectionStatus.pending,
          source: source,
          updatedAt: ts,
        ));
    }
  }

  /// El destinatario acepta una solicitud pendiente.
  ConnectionOutcome accept({
    required RunnerConnection current,
    required String actor,
    DateTime? now,
  }) {
    if (current.status != ConnectionStatus.pending) {
      return ConnectionOutcome(current, changed: false, reason: 'not_pending');
    }
    if (actor != current.recipientUserId) {
      // Nadie acepta en nombre de otro.
      return ConnectionOutcome(current,
          changed: false, reason: 'not_recipient');
    }
    final ts = now ?? DateTime.now();
    return ConnectionOutcome(current.copyWith(
      status: ConnectionStatus.accepted,
      acceptedAt: ts,
      updatedAt: ts,
    ));
  }

  ConnectionOutcome decline({
    required RunnerConnection current,
    required String actor,
    DateTime? now,
  }) {
    if (current.status != ConnectionStatus.pending ||
        actor != current.recipientUserId) {
      return ConnectionOutcome(current, changed: false, reason: 'invalid');
    }
    return ConnectionOutcome(current.copyWith(
      status: ConnectionStatus.declined,
      updatedAt: now ?? DateTime.now(),
    ));
  }

  ConnectionOutcome remove({
    required RunnerConnection current,
    required String actor,
    DateTime? now,
  }) {
    if (!current.involves(actor) ||
        current.status == ConnectionStatus.blocked) {
      return ConnectionOutcome(current, changed: false, reason: 'invalid');
    }
    return ConnectionOutcome(current.copyWith(
      status: ConnectionStatus.removed,
      updatedAt: now ?? DateTime.now(),
    ));
  }

  ConnectionOutcome block({
    required RunnerConnection current,
    required String actor,
    DateTime? now,
  }) {
    if (!current.involves(actor)) {
      return ConnectionOutcome(current,
          changed: false, reason: 'not_participant');
    }
    final ts = now ?? DateTime.now();
    return ConnectionOutcome(current.copyWith(
      status: ConnectionStatus.blocked,
      blockedBy: actor,
      blockedAt: ts,
      updatedAt: ts,
    ));
  }
}
