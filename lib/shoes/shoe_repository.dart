import 'package:cloud_firestore/cloud_firestore.dart';

import 'running_shoe.dart';
import 'shoe_activity_link.dart';

abstract interface class ShoeRepository {
  Stream<List<RunningShoe>> watch(String userId);
  Future<List<RunningShoe>> shoesForUser(String userId);
  Future<void> save(RunningShoe shoe);
  Future<List<ShoeActivityLink>> linksForUser(String userId);
  Future<void> saveLink(ShoeActivityLink link);
}

class FirestoreShoeRepository implements ShoeRepository {
  final _shoes = FirebaseFirestore.instance.collection('shoes');
  final _links = FirebaseFirestore.instance.collection('shoeActivityLinks');

  @override
  Stream<List<RunningShoe>> watch(String userId) => _shoes
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => s.docs.map(_shoeFrom).toList());

  @override
  Future<List<RunningShoe>> shoesForUser(String userId) async {
    final s = await _shoes.where('userId', isEqualTo: userId).get();
    return s.docs.map(_shoeFrom).toList();
  }

  @override
  Future<void> save(RunningShoe s) =>
      _shoes.doc(s.id).set(_shoeTo(s), SetOptions(merge: true));

  @override
  Future<List<ShoeActivityLink>> linksForUser(String userId) async {
    final s = await _links.where('userId', isEqualTo: userId).get();
    return s.docs.map(_linkFrom).toList();
  }

  @override
  Future<void> saveLink(ShoeActivityLink l) =>
      _links.doc(l.id).set(_linkTo(l), SetOptions(merge: true));

  // ── (de)serialización ──────────────────────────────────────────────────────
  static ShoeStatus _status(String? n) {
    for (final v in ShoeStatus.values) {
      if (v.name == n) return v;
    }
    return ShoeStatus.active;
  }

  static ShoeSource _srcOf(String? n) {
    for (final v in ShoeSource.values) {
      if (v.name == n) return v;
    }
    return ShoeSource.manual;
  }

  static Map<String, dynamic> _shoeTo(RunningShoe s) => {
        'userId': s.userId,
        'source': s.source.name,
        'stravaGearId': s.stravaGearId,
        'brand': s.brand,
        'model': s.model,
        'nickname': s.nickname,
        'photoUrl': s.photoUrl,
        'initialDistanceMeters': s.initialDistanceMeters,
        'syncedDistanceMeters': s.syncedDistanceMeters,
        'localDistanceMeters': s.localDistanceMeters,
        'recommendedMaxDistanceMeters': s.recommendedMaxDistanceMeters,
        'status': s.status.name,
        'notes': s.notes,
        'isPrimary': s.isPrimary,
        'retiredDate':
            s.retiredDate == null ? null : Timestamp.fromDate(s.retiredDate!),
        'createdAt': Timestamp.fromDate(s.createdAt),
        'updatedAt': Timestamp.fromDate(s.updatedAt),
        'lastSyncedAt':
            s.lastSyncedAt == null ? null : Timestamp.fromDate(s.lastSyncedAt!),
      };

  static RunningShoe _shoeFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    double num_(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return RunningShoe(
      id: d.id,
      userId: m['userId'] as String,
      source: _srcOf(m['source'] as String?),
      stravaGearId: m['stravaGearId'] as String?,
      brand: m['brand'] as String?,
      model: m['model'] as String?,
      nickname: m['nickname'] as String?,
      photoUrl: m['photoUrl'] as String?,
      initialDistanceMeters: num_('initialDistanceMeters'),
      syncedDistanceMeters: num_('syncedDistanceMeters'),
      localDistanceMeters: num_('localDistanceMeters'),
      recommendedMaxDistanceMeters:
          (m['recommendedMaxDistanceMeters'] as num?)?.toDouble() ?? 800000,
      status: _status(m['status'] as String?),
      notes: m['notes'] as String?,
      isPrimary: m['isPrimary'] as bool? ?? false,
      retiredDate: (m['retiredDate'] as Timestamp?)?.toDate(),
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (m['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSyncedAt: (m['lastSyncedAt'] as Timestamp?)?.toDate(),
    );
  }

  static Map<String, dynamic> _linkTo(ShoeActivityLink l) => {
        'userId': l.userId,
        'activityId': l.activityId,
        'shoeId': l.shoeId,
        'distanceMeters': l.distanceMeters,
        'source': l.source,
      };

  static ShoeActivityLink _linkFrom(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ShoeActivityLink(
      userId: m['userId'] as String,
      activityId: m['activityId'] as String,
      shoeId: m['shoeId'] as String? ?? '',
      distanceMeters: (m['distanceMeters'] as num?)?.toDouble() ?? 0,
      source: m['source'] as String? ?? 'strava',
    );
  }
}
