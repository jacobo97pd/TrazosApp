import 'package:cloud_firestore/cloud_firestore.dart';

import 'zone_conquest.dart';

abstract interface class ZoneConquestRepository {
  Future<ZoneConquest?> get(String id);
  Future<void> save(ZoneConquest c);
  Stream<List<ZoneConquest>> watchForUser(String userId);
  Future<int> countForUser(String userId);
}

class FirestoreZoneConquestRepository implements ZoneConquestRepository {
  final _col = FirebaseFirestore.instance.collection('zone_conquests');

  @override
  Future<ZoneConquest?> get(String id) async {
    final s = await _col.doc(id).get();
    return s.exists ? _from(s) : null;
  }

  @override
  Future<void> save(ZoneConquest c) =>
      _col.doc(c.id).set(_to(c), SetOptions(merge: true));

  @override
  Stream<List<ZoneConquest>> watchForUser(String userId) => _col
      .where('userId', isEqualTo: userId)
      .where('isDeleted', isEqualTo: false)
      .snapshots()
      .map((s) => s.docs.map(_from).toList());

  @override
  Future<int> countForUser(String userId) async {
    final agg = await _col
        .where('userId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .count()
        .get();
    return agg.count ?? 0;
  }

  static Map<String, dynamic> _to(ZoneConquest c) => {
        'userId': c.userId,
        'activityId': c.activityId,
        'zoneId': c.zoneId,
        'createdAt': Timestamp.fromDate(c.createdAt),
        'zoneNameSnapshot': c.zoneNameSnapshot,
        'city': c.city,
        'distanceSnapshot': c.distanceSnapshot,
        'durationSnapshot': c.durationSnapshot,
        'paceSnapshot': c.paceSnapshot,
        'elevationSnapshot': c.elevationSnapshot,
        'areaM2Snapshot': c.areaM2Snapshot,
        'isDeleted': c.isDeleted,
      };

  static ZoneConquest _from(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    double num_(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return ZoneConquest(
      id: d.id,
      userId: m['userId'] as String,
      activityId: m['activityId'] as String? ?? '',
      zoneId: m['zoneId'] as String?,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      zoneNameSnapshot: m['zoneNameSnapshot'] as String? ?? '',
      city: m['city'] as String? ?? '',
      distanceSnapshot: num_('distanceSnapshot'),
      durationSnapshot: (m['durationSnapshot'] as num?)?.toInt() ?? 0,
      paceSnapshot: num_('paceSnapshot'),
      elevationSnapshot: num_('elevationSnapshot'),
      areaM2Snapshot: num_('areaM2Snapshot'),
      isDeleted: m['isDeleted'] as bool? ?? false,
    );
  }
}
