import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'achievement.dart';
import 'challenge.dart';
import 'progression_repository_firestore.dart';
import 'runner_progress.dart';
import 'runner_progress_repository.dart';
import 'runner_progression_service.dart';

final runnerProgressRepositoryProvider =
    Provider<RunnerProgressRepository>((_) => FirestoreRunnerProgressRepository());

const _service = RunnerProgressionService();

// Estado de progresión del usuario actual (en vivo desde users/{uid}).
final runnerProgressProvider = StreamProvider.autoDispose<RunnerProgress>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const RunnerProgress());
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map(
      (s) => FirestoreRunnerProgressRepository.fromMap(
          s.data()?['progression'] as Map<String, dynamic>?));
});

// Métricas del corredor para retos/logros (las no rastreadas quedan en 0).
RunnerStats _statsFrom(UserModel? u, RunnerProgress p) => RunnerStats(
      totalKm: u?.totalKm ?? 0,
      challengesCompleted: p.processedChallengeIds.length,
    );

final runnerStatsProvider = Provider.autoDispose<RunnerStats>((ref) {
  final u = ref.watch(userProfileProvider).valueOrNull;
  final p = ref.watch(runnerProgressProvider).valueOrNull ?? const RunnerProgress();
  return _statsFrom(u, p);
});

final challengeStatusesProvider =
    Provider.autoDispose<List<ChallengeStatus>>((ref) {
  final stats = ref.watch(runnerStatsProvider);
  final p = ref.watch(runnerProgressProvider).valueOrNull ?? const RunnerProgress();
  return [
    for (final c in kChallengesCatalog)
      ChallengeStatus(
        challenge: c,
        current: stats.valueOf(c.metric),
        claimed: p.processedChallengeIds.contains(c.id),
      ),
  ];
});

final progressionControllerProvider =
    Provider((ref) => ProgressionController(ref));

class ProgressionController {
  ProgressionController(this.ref);
  final Ref ref;

  // Reclama un reto: concede XP una sola vez y persiste. Devuelve el resultado
  // para la celebración (o null si no aplica).
  Future<ProgressionOutcome?> claim(String challengeId) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return null;

    Challenge? ch;
    for (final c in kChallengesCatalog) {
      if (c.id == challengeId) ch = c;
    }
    if (ch == null) return null;

    final repo = ref.read(runnerProgressRepositoryProvider);
    final current = await repo.load(uid);
    final stats = ref.read(runnerStatsProvider);

    final out = _service.completeChallenge(
      current: current,
      challengeId: challengeId,
      difficulty: ch.difficulty,
      period: ch.period,
      statsAfter: stats,
    );
    if (out.applied) await repo.save(uid, out.progress);
    return out;
  }
}
