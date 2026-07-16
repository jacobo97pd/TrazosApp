enum LeaderboardScope { connections, privateChallenge, group, club }

enum LeaderboardPeriod { weekly, monthly, allTime }

/// Candidato a una clasificación privada. [consent] = el usuario acepta
/// aparecer en ESTA clasificación (appearInLeaderboards / elección por ámbito).
class LeaderboardCandidate {
  const LeaderboardCandidate({
    required this.uid,
    required this.value,
    required this.consent,
  });
  final String uid;
  final num value;
  final bool consent;
}

class RankedEntry {
  const RankedEntry({
    required this.uid,
    required this.value,
    required this.rank,
    required this.tied,
  });
  final String uid;
  final num value;
  final int rank; // 1-indexed
  final bool tied; // comparte rango con otro
}

/// Clasificaciones EXCLUSIVAMENTE internas de Trazos. Solo entran quienes dan
/// consentimiento. Regla de empate PÚBLICA y estable: mismo valor = mismo rango
/// (ranking de competición estándar: 1, 2, 2, 4).
class SocialLeaderboardService {
  const SocialLeaderboardService();

  List<RankedEntry> rank(List<LeaderboardCandidate> candidates) {
    final eligible = candidates.where((c) => c.consent).toList()
      ..sort((x, y) => y.value.compareTo(x.value));

    final result = <RankedEntry>[];
    for (var i = 0; i < eligible.length; i++) {
      final c = eligible[i];
      // Empate: mismo valor que el anterior → mismo rango; si no, rango = i+1.
      final samePrev = i > 0 && eligible[i - 1].value == c.value;
      final sameNext =
          i < eligible.length - 1 && eligible[i + 1].value == c.value;
      final rank = samePrev ? result[i - 1].rank : i + 1;
      result.add(RankedEntry(
        uid: c.uid,
        value: c.value,
        rank: rank,
        tied: samePrev || sameNext,
      ));
    }
    return result;
  }
}
