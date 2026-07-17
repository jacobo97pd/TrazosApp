import 'package:cloud_firestore/cloud_firestore.dart';

import 'conquest_post.dart';

abstract interface class ConquestPostRepository {
  Future<void> create(ConquestPost post);
  Future<void> update(ConquestPost post);
  Stream<List<ConquestPost>> watchForUser(String userId,
      {bool includePrivate = true});
}

class FirestoreConquestPostRepository implements ConquestPostRepository {
  final _col = FirebaseFirestore.instance.collection('conquest_posts');

  @override
  Future<void> create(ConquestPost p) => _col.doc(p.id).set(_to(p));

  @override
  Future<void> update(ConquestPost p) => _col.doc(p.id).set(
        {
          'visibility': p.visibility.name,
          'caption': p.caption,
          'isArchived': p.isArchived,
          'isDeleted': p.isDeleted,
          'moderationStatus': p.moderationStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

  @override
  Stream<List<ConquestPost>> watchForUser(String userId,
          {bool includePrivate = true}) =>
      _col
          .where('userId', isEqualTo: userId)
          .where('isDeleted', isEqualTo: false)
          .snapshots()
          .map((s) => s.docs.map(_from).toList());

  static T _en<T>(List<T> v, String? n, T fb) {
    for (final e in v) {
      if ((e as Enum).name == n) return e;
    }
    return fb;
  }

  static Map<String, dynamic> _to(ConquestPost p) => {
        'userId': p.userId,
        'type': p.type.name,
        'visibility': p.visibility.name,
        'createdAt': Timestamp.fromDate(p.createdAt),
        'zoneId': p.zoneId,
        'activityId': p.activityId,
        'challengeId': p.challengeId,
        'achievementId': p.achievementId,
        'caption': p.caption,
        'mediaUrl': p.mediaUrl,
        'thumbnailUrl': p.thumbnailUrl,
        'expiresAt':
            p.expiresAt == null ? null : Timestamp.fromDate(p.expiresAt!),
        'isArchived': p.isArchived,
        'isDeleted': p.isDeleted,
        'locationPrivacyMode': p.locationPrivacyMode.name,
        'zoneNameSnapshot': p.zoneNameSnapshot,
        'distanceSnapshot': p.distanceSnapshot,
        'durationSnapshot': p.durationSnapshot,
        'paceSnapshot': p.paceSnapshot,
        'elevationSnapshot': p.elevationSnapshot,
        // Contadores iniciales; el cliente no los sube en updates.
        'likesCount': 0,
        'commentsCount': 0,
        'reportCount': 0,
        'moderationStatus': 'ok',
      };

  static ConquestPost _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    double num_(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return ConquestPost(
      id: d.id,
      userId: m['userId'] as String,
      type: _en(ConquestType.values, m['type'] as String?, ConquestType.text),
      visibility: _en(ConquestVisibility.values, m['visibility'] as String?,
          ConquestVisibility.onlyMe),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate(),
      zoneId: m['zoneId'] as String?,
      activityId: m['activityId'] as String?,
      challengeId: m['challengeId'] as String?,
      achievementId: m['achievementId'] as String?,
      caption: m['caption'] as String? ?? '',
      mediaUrl: m['mediaUrl'] as String?,
      thumbnailUrl: m['thumbnailUrl'] as String?,
      expiresAt: (m['expiresAt'] as Timestamp?)?.toDate(),
      isArchived: m['isArchived'] as bool? ?? false,
      isDeleted: m['isDeleted'] as bool? ?? false,
      locationPrivacyMode: _en(LocationPrivacyMode.values,
          m['locationPrivacyMode'] as String?, LocationPrivacyMode.city),
      zoneNameSnapshot: m['zoneNameSnapshot'] as String? ?? '',
      distanceSnapshot: num_('distanceSnapshot'),
      durationSnapshot: (m['durationSnapshot'] as num?)?.toInt() ?? 0,
      paceSnapshot: num_('paceSnapshot'),
      elevationSnapshot: num_('elevationSnapshot'),
      likesCount: (m['likesCount'] as num?)?.toInt() ?? 0,
      commentsCount: (m['commentsCount'] as num?)?.toInt() ?? 0,
      reportCount: (m['reportCount'] as num?)?.toInt() ?? 0,
      moderationStatus: m['moderationStatus'] as String? ?? 'ok',
    );
  }
}
