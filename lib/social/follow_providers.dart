import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'follow_repository.dart';

final followRepositoryProvider =
    Provider<FollowRepository>((_) => FollowRepository());

/// ¿El usuario actual sigue a [userId]?
final isFollowingProvider =
    StreamProvider.autoDispose.family<bool, String>((ref, userId) {
  final me = ref.watch(authStateProvider).valueOrNull?.uid;
  if (me == null || me == userId) return Stream.value(false);
  return ref.watch(followRepositoryProvider).watchIsFollowing(me, userId);
});

final followerCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).followerCount(userId));

final followingCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) =>
        ref.watch(followRepositoryProvider).followingCount(userId));

final followControllerProvider =
    Provider<FollowController>((ref) => FollowController(ref));

class FollowController {
  FollowController(this._ref);
  final Ref _ref;

  Future<void> toggle(String userId, {required bool currentlyFollowing}) async {
    final me = _ref.read(authStateProvider).valueOrNull?.uid;
    if (me == null || me == userId) return;
    final repo = _ref.read(followRepositoryProvider);
    if (currentlyFollowing) {
      await repo.unfollow(me, userId);
    } else {
      await repo.follow(me, userId);
    }
    _ref.invalidate(followerCountProvider(userId));
  }
}
