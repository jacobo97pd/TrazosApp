import 'package:cloud_firestore/cloud_firestore.dart';

import '../progression/progression_config.dart';
import 'private_challenge.dart';

abstract interface class PrivateChallengeRepository {
  Future<PrivateChallenge?> get(String id);
  Future<void> save(PrivateChallenge c);
  Stream<List<PrivateChallenge>> watchForUser(String uid);
}

class FirestorePrivateChallengeRepository
    implements PrivateChallengeRepository {
  final _col = FirebaseFirestore.instance.collection('privateChallenges');

  @override
  Future<PrivateChallenge?> get(String id) async {
    final s = await _col.doc(id).get();
    return s.exists ? _fromDoc(s) : null;
  }

  @override
  Future<void> save(PrivateChallenge c) =>
      _col.doc(c.id).set(_toMap(c), SetOptions(merge: true));

  @override
  Stream<List<PrivateChallenge>> watchForUser(String uid) => _col
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList());

  static Map<String, dynamic> _toMap(PrivateChallenge c) => {
        'creatorId': c.creatorId,
        'invited': c.invited.toList(),
        'accepted': c.accepted.toList(),
        'participants': c.participants.toList(),
        'modality': c.modality.name,
        'metric': c.metric.name,
        'target': c.target,
        'difficulty': c.difficulty.name,
        'period': c.period.name,
        'startAt': Timestamp.fromDate(c.startAt),
        'endAt': Timestamp.fromDate(c.endAt),
        'status': c.status.name,
        'progressByUser': c.progressByUser,
        'rewardedUserIds': c.rewardedUserIds.toList(),
      };

  static T _en<T>(List<T> values, String? name, T fallback) {
    for (final v in values) {
      if ((v as Enum).name == name) return v;
    }
    return fallback;
  }

  static PrivateChallenge _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return PrivateChallenge(
      id: d.id,
      creatorId: m['creatorId'] as String,
      invited: Set<String>.from(m['invited'] as List? ?? const []),
      accepted: Set<String>.from(m['accepted'] as List? ?? const []),
      modality: _en(ChallengeModality.values, m['modality'] as String?,
          ChallengeModality.oneVsOne),
      metric: _en(PrivateChallengeMetric.values, m['metric'] as String?,
          PrivateChallengeMetric.distanceKm),
      target: (m['target'] as num?) ?? 0,
      difficulty: _en(ChallengeDifficulty.values, m['difficulty'] as String?,
          ChallengeDifficulty.medium),
      period: _en(ChallengePeriod.values, m['period'] as String?,
          ChallengePeriod.weekly),
      startAt: (m['startAt'] as Timestamp).toDate(),
      endAt: (m['endAt'] as Timestamp).toDate(),
      status: _en(PrivateChallengeStatus.values, m['status'] as String?,
          PrivateChallengeStatus.draft),
      progressByUser: (m['progressByUser'] as Map?)
              ?.map((k, v) => MapEntry(k as String, v as num)) ??
          const {},
      rewardedUserIds:
          Set<String>.from(m['rewardedUserIds'] as List? ?? const []),
    );
  }
}
