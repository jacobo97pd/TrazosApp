/// Estado de una relación entre dos corredores de Trazos.
enum ConnectionStatus {
  suggested,
  pending,
  accepted,
  declined,
  blocked,
  removed
}

/// Origen de la conexión.
enum ConnectionSource { stravaMatch, username, inviteLink, qr, challenge, club }

/// Relación entre dos usuarios. El documento es ÚNICO por par (id determinista),
/// así se impiden duplicados y solicitudes cruzadas: ambas direcciones apuntan
/// al mismo doc. La dirección se guarda en [requesterUserId]/[recipientUserId].
class RunnerConnection {
  const RunnerConnection({
    required this.id,
    required this.requesterUserId,
    required this.recipientUserId,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.acceptedAt,
    this.blockedAt,
    this.blockedBy,
  });

  final String id;
  final String requesterUserId;
  final String recipientUserId;
  final ConnectionStatus status;
  final ConnectionSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? acceptedAt;
  final DateTime? blockedAt;
  final String? blockedBy;

  /// Los dos participantes (ordenados) — usado en reglas y consultas.
  List<String> get participants {
    final a = requesterUserId, b = recipientUserId;
    return (a.compareTo(b) <= 0) ? [a, b] : [b, a];
  }

  /// id estable para un par de usuarios (independiente del orden).
  static String idFor(String a, String b) =>
      (a.compareTo(b) <= 0) ? '${a}_$b' : '${b}_$a';

  bool involves(String uid) => uid == requesterUserId || uid == recipientUserId;

  String other(String uid) =>
      uid == requesterUserId ? recipientUserId : requesterUserId;

  RunnerConnection copyWith({
    String? requesterUserId,
    String? recipientUserId,
    ConnectionStatus? status,
    ConnectionSource? source,
    DateTime? updatedAt,
    DateTime? acceptedAt,
    DateTime? blockedAt,
    String? blockedBy,
  }) =>
      RunnerConnection(
        id: id,
        requesterUserId: requesterUserId ?? this.requesterUserId,
        recipientUserId: recipientUserId ?? this.recipientUserId,
        status: status ?? this.status,
        source: source ?? this.source,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        blockedAt: blockedAt ?? this.blockedAt,
        blockedBy: blockedBy ?? this.blockedBy,
      );
}
