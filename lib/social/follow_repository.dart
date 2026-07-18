import 'package:cloud_firestore/cloud_firestore.dart';

/// Seguimiento unidireccional entre corredores (estilo Instagram).
/// Documento determinista `follows/{followerId}_{followeeId}` → sin duplicados.
class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col => _db.collection('follows');

  static String idFor(String follower, String followee) =>
      '${follower}_$followee';

  Future<void> follow(String follower, String followee) {
    if (follower == followee) return Future.value();
    return _col.doc(idFor(follower, followee)).set({
      'followerId': follower,
      'followeeId': followee,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollow(String follower, String followee) =>
      _col.doc(idFor(follower, followee)).delete();

  Stream<bool> watchIsFollowing(String follower, String followee) => _col
      .doc(idFor(follower, followee))
      .snapshots()
      .map((snapshot) => snapshot.exists);

  Future<int> followerCount(String userId) async =>
      (await _col.where('followeeId', isEqualTo: userId).count().get()).count ??
      0;

  Future<int> followingCount(String userId) async =>
      (await _col.where('followerId', isEqualTo: userId).count().get()).count ??
      0;
}
