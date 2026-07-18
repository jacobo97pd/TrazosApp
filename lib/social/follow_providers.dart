import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'follow_repository.dart';

final followRepositoryProvider =
    Provider<FollowRepository>((_) => FollowRepository());

/// ¿Es privada la cuenta de [userId]? (lee users/{uid}.social.private)
final runnerIsPrivateProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, userId) async {
  final snap =
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
  final social = snap.data()?['social'] as Map<String, dynamic>?;
  return social?['private'] as bool? ?? false;
});

/// Estado de seguimiento del usuario actual hacia [userId].
final followStatusProvider =
    StreamProvider.autoDispose.family<FollowStatus, String>((ref, userId) {
  final me = ref.watch(authStateProvider).valueOrNull?.uid;
  if (me == null || me == userId) return Stream.value(FollowStatus.none);
  return ref.watch(followRepositoryProvider).watchStatus(me, userId);
});

final followerCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).followerCount(userId));

final followingCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).followingCount(userId));

final followersProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).watchFollowers(userId));

final followingProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).watchFollowing(userId));

/// Solicitudes pendientes que ha recibido el usuario actual.
final myPendingRequestsProvider =
    StreamProvider.autoDispose<List<String>>((ref) {
  final me = ref.watch(authStateProvider).valueOrNull?.uid;
  if (me == null) return Stream.value(const []);
  return ref.watch(followRepositoryProvider).watchPendingRequests(me);
});

final followControllerProvider =
    Provider<FollowController>((ref) => FollowController(ref));

class FollowController {
  FollowController(this._ref);
  final Ref _ref;

  String? get _me => _ref.read(authStateProvider).valueOrNull?.uid;

  /// Alterna seguir/dejar de seguir según el estado actual.
  Future<void> toggle(String userId, FollowStatus status) async {
    final me = _me;
    if (me == null || me == userId) return;
    final repo = _ref.read(followRepositoryProvider);
    if (status == FollowStatus.none) {
      final isPrivate =
          await _ref.read(runnerIsPrivateProvider(userId).future);
      await repo.follow(me, userId, targetIsPrivate: isPrivate);
    } else {
      // pending → cancela la solicitud; accepted → deja de seguir.
      await repo.unfollow(me, userId);
    }
    _ref.invalidate(followerCountProvider(userId));
  }

  /// El usuario actual aprueba la solicitud de [followerId].
  Future<void> approve(String followerId) async {
    final me = _me;
    if (me == null) return;
    await _ref.read(followRepositoryProvider).approve(followerId, me);
    _ref.invalidate(followerCountProvider(me));
  }

  /// El usuario actual rechaza/expulsa a [followerId].
  Future<void> reject(String followerId) async {
    final me = _me;
    if (me == null) return;
    await _ref.read(followRepositoryProvider).removeFollower(followerId, me);
    _ref.invalidate(followerCountProvider(me));
  }
}
