import '../progression/progression_config.dart';
import 'private_challenge.dart';

/// Lógica pura de retos privados. No toca Firebase ni concede XP directamente:
/// determina estado/ganadores; la XP la aplica el motor de progresión con
/// `completeChallenge(challengeId = reto.id)` (idempotente) para los que estén
/// en `pendingRewards()`.
class PrivateChallengeService {
  const PrivateChallengeService();

  PrivateChallenge create({
    required String id,
    required String creator,
    required Set<String> invited,
    required ChallengeModality modality,
    required PrivateChallengeMetric metric,
    required ChallengeDifficulty difficulty,
    required ChallengePeriod period,
    required DateTime startAt,
    required DateTime endAt,
    num target = 0,
  }) {
    final cleanInvited = invited.where((u) => u != creator).toSet();
    return PrivateChallenge(
      id: id,
      creatorId: creator,
      invited: cleanInvited,
      accepted: {creator}, // el creador participa
      modality: modality,
      metric: metric,
      target: target,
      difficulty: difficulty,
      period: period,
      startAt: startAt,
      endAt: endAt,
      status: cleanInvited.isEmpty
          ? PrivateChallengeStatus.draft
          : PrivateChallengeStatus.invited,
    );
  }

  /// Un invitado acepta. Se activa cuando hay ≥2 participantes.
  PrivateChallenge accept(PrivateChallenge c, String uid) {
    if (!c.invited.contains(uid)) return c; // debe estar invitado
    final accepted = {...c.accepted, uid};
    final invited = {...c.invited}..remove(uid);
    final active = accepted.length >= 2;
    return c.copyWith(
      accepted: accepted,
      invited: invited,
      status: active && c.status == PrivateChallengeStatus.invited
          ? PrivateChallengeStatus.active
          : c.status,
    );
  }

  PrivateChallenge decline(PrivateChallenge c, String uid) =>
      c.invited.contains(uid)
          ? c.copyWith(invited: {...c.invited}..remove(uid))
          : c;

  /// Fija el progreso ABSOLUTO de un participante (idempotente). Solo si el
  /// usuario participa y el reto está activo (nadie sin autorizar entra).
  PrivateChallenge updateProgress(PrivateChallenge c, String uid, num value) {
    if (c.status != PrivateChallengeStatus.active ||
        !c.accepted.contains(uid)) {
      return c;
    }
    return c.copyWith(progressByUser: {...c.progressByUser, uid: value});
  }

  /// Evalúa al llegar la fecha fin: completed (coop con objetivo cumplido o
  /// competitivo con progreso) o expired.
  PrivateChallenge evaluate(PrivateChallenge c, DateTime now) {
    if (c.status != PrivateChallengeStatus.active) return c;
    if (now.isBefore(c.endAt)) return c;

    final done =
        c.isCoop ? c.groupProgress >= c.target : c.winners().isNotEmpty;
    return c.copyWith(
      status: done
          ? PrivateChallengeStatus.completed
          : PrivateChallengeStatus.expired,
    );
  }

  PrivateChallenge cancel(PrivateChallenge c, String uid) {
    if (uid != c.creatorId) return c; // solo el creador cancela
    if (c.status == PrivateChallengeStatus.completed) return c;
    return c.copyWith(status: PrivateChallengeStatus.cancelled);
  }

  /// Marca a unos usuarios como ya recompensados (tras aplicar la XP).
  PrivateChallenge markRewarded(PrivateChallenge c, Iterable<String> uids) =>
      c.copyWith(rewardedUserIds: {...c.rewardedUserIds, ...uids});
}
