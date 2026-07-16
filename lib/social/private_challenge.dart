import '../progression/progression_config.dart';

enum ChallengeModality { oneVsOne, group, coop, individualShared }

enum PrivateChallengeMetric {
  distanceKm,
  activeDays,
  newStreets,
  zonesExplored,
  elevation
}

enum PrivateChallengeStatus {
  draft,
  invited,
  active,
  completed,
  expired,
  cancelled
}

/// Reto privado entre conexiones de Trazos. Entidad interna: su progreso se
/// calcula con actividades que cada participante ya ha autorizado (valores
/// absolutos → idempotentes). Recompensa: solo XP/nivel/estrellas/logros.
class PrivateChallenge {
  const PrivateChallenge({
    required this.id,
    required this.creatorId,
    required this.invited,
    required this.accepted,
    required this.modality,
    required this.metric,
    required this.target,
    required this.difficulty,
    required this.period,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.progressByUser = const {},
    this.rewardedUserIds = const {},
  });

  final String id;
  final String creatorId;
  final Set<String> invited; // pendientes de aceptar
  final Set<String> accepted; // participan (incluye al creador)
  final ChallengeModality modality;
  final PrivateChallengeMetric metric;
  final num target; // para coop / individualShared
  final ChallengeDifficulty difficulty;
  final ChallengePeriod period;
  final DateTime startAt;
  final DateTime endAt;
  final PrivateChallengeStatus status;
  final Map<String, num> progressByUser;
  final Set<String> rewardedUserIds;

  Set<String> get participants => {...accepted, ...invited};

  bool get isCoop =>
      modality == ChallengeModality.coop ||
      modality == ChallengeModality.individualShared;

  num get groupProgress =>
      accepted.fold<num>(0, (s, u) => s + (progressByUser[u] ?? 0));

  /// Ganador(es): en competitivo, el/los de mayor progreso (puede haber empate).
  /// En coop no hay "ganador" individual (gana el equipo si llega al objetivo).
  List<String> winners() {
    if (isCoop) return groupProgress >= target ? accepted.toList() : const [];
    num best = -1;
    for (final u in accepted) {
      final v = progressByUser[u] ?? 0;
      if (v > best) best = v;
    }
    if (best <= 0) return const [];
    return [
      for (final u in accepted)
        if ((progressByUser[u] ?? 0) == best) u
    ];
  }

  /// Quién debe recibir XP al completar (sin los ya recompensados).
  List<String> pendingRewards() {
    if (status != PrivateChallengeStatus.completed) return const [];
    final base = isCoop
        ? (groupProgress >= target ? accepted.toList() : const <String>[])
        : winners();
    return [
      for (final u in base)
        if (!rewardedUserIds.contains(u)) u
    ];
  }

  PrivateChallenge copyWith({
    Set<String>? invited,
    Set<String>? accepted,
    PrivateChallengeStatus? status,
    Map<String, num>? progressByUser,
    Set<String>? rewardedUserIds,
  }) =>
      PrivateChallenge(
        id: id,
        creatorId: creatorId,
        invited: invited ?? this.invited,
        accepted: accepted ?? this.accepted,
        modality: modality,
        metric: metric,
        target: target,
        difficulty: difficulty,
        period: period,
        startAt: startAt,
        endAt: endAt,
        status: status ?? this.status,
        progressByUser: progressByUser ?? this.progressByUser,
        rewardedUserIds: rewardedUserIds ?? this.rewardedUserIds,
      );
}
