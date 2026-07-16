import 'package:cloud_firestore/cloud_firestore.dart';

import 'runner_progress.dart';
import 'runner_progress_repository.dart';

/// Persiste la progresión como campo `progression` (mapa) en users/{uid}.
/// El usuario ya puede escribir su propio doc, así que no hacen falta reglas
/// nuevas. Los arrays viven dentro del mapa (Firestore lo permite).
class FirestoreRunnerProgressRepository implements RunnerProgressRepository {
  final _users = FirebaseFirestore.instance.collection('users');

  @override
  Future<RunnerProgress> load(String userId) async {
    final snap = await _users.doc(userId).get();
    return fromMap(snap.data()?['progression'] as Map<String, dynamic>?);
  }

  @override
  Future<void> save(String userId, RunnerProgress p) async {
    await _users.doc(userId).set({'progression': toMap(p)}, SetOptions(merge: true));
  }

  static Map<String, dynamic> toMap(RunnerProgress p) => {
        'totalXp': p.totalXp,
        'achievementUnlockDates': p.achievementUnlockDates
            .map((k, v) => MapEntry(k, Timestamp.fromDate(v))),
        'processedChallengeIds': p.processedChallengeIds.toList(),
        'processedActivityIds': p.processedActivityIds.toList(),
        'levelHistory': [
          for (final e in p.levelHistory)
            {'level': e.level, 'at': Timestamp.fromDate(e.at)},
        ],
      };

  static RunnerProgress fromMap(Map<String, dynamic>? m) {
    if (m == null) return const RunnerProgress();
    return RunnerProgress(
      totalXp: (m['totalXp'] as num?)?.toInt() ?? 0,
      achievementUnlockDates:
          (m['achievementUnlockDates'] as Map?)?.map((k, v) =>
                  MapEntry(k as String, (v as Timestamp).toDate())) ??
              const {},
      processedChallengeIds:
          Set<String>.from(m['processedChallengeIds'] as List? ?? const []),
      processedActivityIds:
          Set<String>.from(m['processedActivityIds'] as List? ?? const []),
      levelHistory: [
        for (final e in (m['levelHistory'] as List? ?? const []))
          LevelUpEvent(
            level: (e['level'] as num).toInt(),
            at: (e['at'] as Timestamp).toDate(),
          ),
      ],
    );
  }
}
