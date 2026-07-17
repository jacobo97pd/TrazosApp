import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../conquest/conquest_feed.dart';
import '../conquest/conquest_post.dart';
import '../conquest/conquest_providers.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/conquest_post_card.dart';

class MyConquestsScreen extends ConsumerStatefulWidget {
  const MyConquestsScreen({super.key});

  @override
  ConsumerState<MyConquestsScreen> createState() => _MyConquestsScreenState();
}

class _MyConquestsScreenState extends ConsumerState<MyConquestsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        logAnalyticsBestEffort(
          () => ref.read(analyticsServiceProvider).logMyConquestsView(),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final postsAsync = ref.watch(myPostsProvider);
    final user = ref.watch(userProfileProvider).valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Mis conquistas')),
      body: postsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (error, _) => _ErrorState(
          message: 'No se pudieron cargar tus conquistas.',
          onRetry: () => ref.invalidate(myPostsProvider),
        ),
        data: (posts) {
          final visible = posts.where((post) => !post.isDeleted).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          if (visible.isEmpty) return const _EmptyState();

          return ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            itemCount: visible.length,
            itemBuilder: (context, index) {
              final post = visible[index];
              final item = ConquestFeedItem(
                post: post,
                author: ConquestAuthor(
                  userId: post.userId,
                  displayName: user?.displayName ?? 'Tú',
                  photoUrl: user?.photoUrl,
                ),
              );
              return Column(
                children: [
                  if (post.moderationStatus != 'ok')
                    _ModerationNotice(status: post.moderationStatus),
                  _OwnershipMeta(post: post),
                  ConquestPostCard(
                    item: item,
                    showActions: false,
                    useThumbnail: true,
                    onTap: () => context.push(
                      '${AppRoutes.conquests}/${post.id}',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _OwnershipMeta extends ConsumerWidget {
  const _OwnershipMeta({required this.post});

  final ConquestPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visibility = switch (post.visibility) {
      ConquestVisibility.public => 'Pública',
      ConquestVisibility.connections => 'Conexiones',
      ConquestVisibility.group => 'Grupo',
      ConquestVisibility.onlyMe => 'Solo yo',
    };
    final views =
        post.isStory ? ref.watch(storyViewCountProvider(post.id)) : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
      child: Row(
        children: [
          Icon(
            post.visibility == ConquestVisibility.onlyMe
                ? Icons.lock_outline_rounded
                : Icons.visibility_outlined,
            size: 16,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            post.isArchived ? '$visibility · Archivada' : visibility,
            style: AppTextStyles.caption,
          ),
          const Spacer(),
          if (views != null)
            Text('$views visualizaciones', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ModerationNotice extends StatelessWidget {
  const _ModerationNotice({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'under_review' => 'Esta publicación está en revisión',
      'hidden' => 'Esta publicación está oculta',
      'removed' => 'Esta publicación fue retirada',
      _ => 'Estado de moderación: $status',
    };
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.caption.copyWith(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.landscape_outlined,
                size: 52,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text('Aún no has compartido conquistas',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Después de conquistar una zona podrás guardar una foto, '
                'una historia o un recuerdo.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, style: AppTextStyles.bodyMedium),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
