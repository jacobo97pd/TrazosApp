import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de un seguimiento. En cuentas públicas se crea directamente
/// [accepted]; en privadas nace [pending] hasta que el seguido lo aprueba.
enum FollowStatus { none, pending, accepted }

FollowStatus followStatusFromName(String? name) => switch (name) {
      'pending' => FollowStatus.pending,
      'accepted' => FollowStatus.accepted,
      _ => FollowStatus.none,
    };

/// Seguimiento unidireccional entre corredores (estilo Instagram).
/// Documento determinista `follows/{followerId}_{followeeId}` → sin duplicados.
class FollowRepository {
  FollowRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('follows');

  static String idFor(String follower, String followee) =>
      '${follower}_$followee';

  /// Sigue a [followee]. En cuentas privadas queda pendiente de aprobación.
  Future<void> follow(
    String follower,
    String followee, {
    required bool targetIsPrivate,
  }) {
    if (follower == followee) return Future.value();
    return _col.doc(idFor(follower, followee)).set({
      'followerId': follower,
      'followeeId': followee,
      'status': targetIsPrivate ? 'pending' : 'accepted',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deja de seguir o cancela una solicitud (borra el propio doc).
  Future<void> unfollow(String follower, String followee) =>
      _col.doc(idFor(follower, followee)).delete();

  /// El seguido aprueba una solicitud pendiente.
  Future<void> approve(String follower, String followee) =>
      _col.doc(idFor(follower, followee)).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// El seguido rechaza una solicitud o expulsa a un seguidor (borra el doc).
  Future<void> removeFollower(String follower, String followee) =>
      _col.doc(idFor(follower, followee)).delete();

  Stream<FollowStatus> watchStatus(String follower, String followee) => _col
      .doc(idFor(follower, followee))
      .snapshots()
      .map((s) => s.exists
          ? followStatusFromName(s.data()?['status'] as String?)
          : FollowStatus.none);

  Future<int> followerCount(String userId) async => (await _col
              .where('followeeId', isEqualTo: userId)
              .where('status', isEqualTo: 'accepted')
              .count()
              .get())
          .count ??
      0;

  Future<int> followingCount(String userId) async => (await _col
              .where('followerId', isEqualTo: userId)
              .where('status', isEqualTo: 'accepted')
              .count()
              .get())
          .count ??
      0;

  /// IDs de quienes siguen a [userId] (aceptados).
  Stream<List<String>> watchFollowers(String userId) => _col
      .where('followeeId', isEqualTo: userId)
      .where('status', isEqualTo: 'accepted')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => d.data()['followerId'] as String).toList());

  /// IDs a quienes sigue [userId] (aceptados).
  Stream<List<String>> watchFollowing(String userId) => _col
      .where('followerId', isEqualTo: userId)
      .where('status', isEqualTo: 'accepted')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => d.data()['followeeId'] as String).toList());

  /// Solicitudes de seguimiento pendientes que ha recibido [userId].
  Stream<List<String>> watchPendingRequests(String userId) => _col
      .where('followeeId', isEqualTo: userId)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) =>
          s.docs.map((d) => d.data()['followerId'] as String).toList());
}
