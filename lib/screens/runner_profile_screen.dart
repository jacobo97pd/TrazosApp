import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../conquest/conquest_feed.dart';
import '../conquest/conquest_feed_providers.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../social/follow_repository.dart';
import '../social/follow_providers.dart';
import '../widgets/avatar_marker.dart';

/// Perfil público de otro corredor (se abre al tocar su avatar en el mapa).
class RunnerProfileScreen extends ConsumerWidget {
  const RunnerProfileScreen({super.key, required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final future = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .withConverter<UserModel>(
          fromFirestore: (s, _) => UserModel.fromFirestore(s),
          toFirestore: (m, _) => m.toFirestore(),
        )
        .get();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Corredor')),
      body: FutureBuilder<DocumentSnapshot<UserModel>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.accent));
          }
          final user = snap.data?.data();
          if (user == null) {
            return const Center(child: Text('Corredor no encontrado'));
          }
          return _Content(uid: uid, user: user);
        },
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.uid, required this.user});
  final String uid;
  final UserModel user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = user.photoUrl?.trim();
    final hasPhoto = photo != null && photo.isNotEmpty;
    final myUid = ref.watch(authStateProvider).valueOrNull?.uid;
    final isSelf = myUid == uid;
    final status =
        ref.watch(followStatusProvider(uid)).valueOrNull ?? FollowStatus.none;
    final isPrivate =
        ref.watch(runnerIsPrivateProvider(uid)).valueOrNull ?? false;
    final canSeeContent =
        isSelf || !isPrivate || status == FollowStatus.accepted;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.gradientAccent,
            ),
            child: CircleAvatar(
              radius: 52,
              backgroundColor: AppColors.surfaceAlt,
              backgroundImage: hasPhoto ? NetworkImage(photo) : null,
              child: hasPhoto
                  ? null
                  : Text(initialsOf(user.displayName),
                      style: AppTextStyles.displayMedium),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            user.displayName.trim().isEmpty ? 'Runner' : user.displayName,
            style: AppTextStyles.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            isPrivate ? 'Nivel ${user.level} · Cuenta privada' : 'Nivel ${user.level}',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          _CountsRow(uid: uid),
          if (!isSelf) ...[
            const SizedBox(height: 16),
            _FollowButton(uid: uid, status: status),
          ],
          const SizedBox(height: 24),
          if (canSeeContent) ...[
            _StoriesRow(stories: ref.watch(runnerStoriesProvider(uid))),
            Row(
              children: [
                Expanded(
                  child: _Stat(
                    label: 'TERRITORIO',
                    value: _formatArea(user.totalAreaM2),
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Stat(
                    label: 'KM TOTALES',
                    value: user.totalKm
                        .toStringAsFixed(user.totalKm >= 100 ? 0 : 1),
                    color: AppColors.green,
                  ),
                ),
              ],
            ),
          ] else
            const _PrivateWall(),
        ],
      ),
    );
  }
}

/// Contadores de seguidores/seguidos, tocables para ver las listas.
class _CountsRow extends ConsumerWidget {
  const _CountsRow({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followers = ref.watch(followerCountProvider(uid)).valueOrNull;
    final following = ref.watch(followingCountProvider(uid)).valueOrNull;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CountChip(
          value: followers,
          label: 'Seguidores',
          onTap: () => context.push('${AppRoutes.follows}/$uid'),
        ),
        const SizedBox(width: 12),
        _CountChip(
          value: following,
          label: 'Siguiendo',
          onTap: () => context.push('${AppRoutes.follows}/$uid?tab=following'),
        ),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip(
      {required this.value, required this.label, required this.onTap});
  final int? value;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              Text(value?.toString() ?? '—', style: AppTextStyles.titleLarge),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
}

class _PrivateWall extends StatelessWidget {
  const _PrivateWall();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            const Icon(Icons.lock_outline_rounded,
                size: 44, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text('Esta cuenta es privada', style: AppTextStyles.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Sigue a este corredor para ver sus conquistas e historias.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class _FollowButton extends ConsumerWidget {
  const _FollowButton({required this.uid, required this.status});
  final String uid;
  final FollowStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> toggle() =>
        ref.read(followControllerProvider).toggle(uid, status);

    final button = switch (status) {
      FollowStatus.accepted => OutlinedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Siguiendo'),
        ),
      FollowStatus.pending => OutlinedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.hourglass_top_rounded, size: 18),
          label: const Text('Solicitado'),
        ),
      FollowStatus.none => ElevatedButton.icon(
          onPressed: toggle,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
          label: const Text('Seguir'),
        ),
    };
    return SizedBox(width: double.infinity, child: button);
  }
}

class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.stories});
  final AsyncValue<List<ConquestFeedItem>> stories;

  @override
  Widget build(BuildContext context) => stories.maybeWhen(
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Historias', style: AppTextStyles.titleMedium),
              const SizedBox(height: 8),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) => _StoryTile(item: items[i]),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
        orElse: () => const SizedBox.shrink(),
      );
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.item});
  final ConquestFeedItem item;

  @override
  Widget build(BuildContext context) {
    final imageUrl = [item.post.thumbnailUrl, item.post.mediaUrl]
        .whereType<String>()
        .where((v) => v.isNotEmpty)
        .firstOrNull;
    return InkWell(
      onTap: () =>
          context.push('${AppRoutes.conquests}/${item.post.id}'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 72,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.accent, width: 2),
        ),
        child: CircleAvatar(
          radius: 30,
          backgroundColor: AppColors.surfaceAlt,
          foregroundImage:
              imageUrl == null ? null : CachedNetworkImageProvider(imageUrl),
          onForegroundImageError: imageUrl == null ? null : (_, __) {},
          child: const Icon(Icons.auto_awesome_outlined,
              color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: AppTextStyles.headlineMedium.copyWith(color: color)),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.statLabel),
        ],
      ),
    );
  }
}

String _formatArea(double m2) {
  if (m2 >= 100000) return '${(m2 / 1000000).toStringAsFixed(1)} km²';
  if (m2 >= 10000) return '${(m2 / 1000000).toStringAsFixed(2)} km²';
  return '${m2.round()} m²';
}
