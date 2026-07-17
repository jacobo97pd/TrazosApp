import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../conquest/conquest_feed.dart';
import '../conquest/conquest_feed_providers.dart';
import '../conquest/conquest_interaction.dart';
import '../conquest/conquest_interaction_providers.dart';
import '../core/router.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/conquest_comments_sheet.dart';
import '../widgets/conquest_post_card.dart';
import '../widgets/conquest_report_sheet.dart';

class ConquestFeedView extends ConsumerStatefulWidget {
  const ConquestFeedView({super.key});

  @override
  ConsumerState<ConquestFeedView> createState() => _ConquestFeedViewState();
}

class _ConquestFeedViewState extends ConsumerState<ConquestFeedView> {
  final Set<String> _busyReactions = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        logAnalyticsBestEffort(
          () => ref.read(analyticsServiceProvider).logFeedView(),
        );
      }
    });
  }

  Future<void> _setReaction(
    ConquestFeedItem item,
    ReactionType? reaction,
  ) async {
    if (_busyReactions.contains(item.post.id)) return;
    setState(() => _busyReactions.add(item.post.id));
    try {
      final result = await ref
          .read(conquestInteractionControllerProvider)
          .setReaction(item.post.id, reaction);
      ref
          .read(conquestFeedProvider.notifier)
          .applyReaction(item.post.id, result);
      logAnalyticsBestEffort(
        () => ref.read(analyticsServiceProvider).logReaction(
              kind: reaction?.wireValue ?? item.myReaction?.wireValue ?? 'like',
              active: reaction != null,
            ),
      );
    } catch (_) {
      _show('No se pudo actualizar la reacción.');
    } finally {
      if (mounted) setState(() => _busyReactions.remove(item.post.id));
    }
  }

  Future<void> _openComments(ConquestFeedItem item) =>
      showConquestCommentsSheet(
        context,
        postId: item.post.id,
        postOwnerId: item.post.userId,
        onChanged: () => ref.read(conquestFeedProvider.notifier).refresh(),
      );

  Future<void> _refreshAll() async {
    ref.invalidate(conquestStoriesProvider);
    await ref.read(conquestFeedProvider.notifier).refresh();
  }

  Future<void> _loadMore() async {
    try {
      await ref.read(conquestFeedProvider.notifier).loadMore();
    } catch (_) {
      _show('No se pudo cargar la siguiente pÃ¡gina.');
    }
  }

  Future<void> _showActions(ConquestFeedItem item) async {
    final action = await showModalBottomSheet<_FeedAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Reportar publicación'),
              onTap: () => Navigator.pop(context, _FeedAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text('Bloquear a ${item.author.displayName}'),
              onTap: () => Navigator.pop(context, _FeedAction.block),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _FeedAction.report:
        final report = await showConquestReportSheet(
          context,
          postId: item.post.id,
        );
        if (!mounted || report == null) break;
        if (item.post.isStory) ref.invalidate(conquestStoriesProvider);
        if (report.moderationStatus != ConquestModerationStatus.ok) {
          await ref.read(conquestFeedProvider.notifier).refresh();
        }
        _show(
          report.created
              ? 'Gracias. Revisaremos esta publicación.'
              : 'Ya habías reportado esta publicación.',
        );
        break;
      case _FeedAction.block:
        await _confirmBlock(item);
        break;
    }
  }

  Future<void> _confirmBlock(ConquestFeedItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Bloquear a ${item.author.displayName}?'),
        content: const Text(
          'Dejarás de ver sus conquistas y no podréis interactuar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bloquear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(conquestInteractionControllerProvider)
          .blockRunner(item.post.userId);
      logAnalyticsBestEffort(
        () => ref.read(analyticsServiceProvider).logRunnerBlocked(),
      );
      ref.invalidate(blockedRunnerIdsProvider);
      ref.invalidate(conquestStoriesProvider);
      await ref.read(conquestFeedProvider.notifier).refresh();
      _show('${item.author.displayName} ha sido bloqueado.');
    } catch (_) {
      _show('No se pudo bloquear al corredor.');
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(conquestFeedProvider);
    final stories = ref.watch(conquestStoriesProvider);
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    return feed.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      ),
      error: (_, __) => _FeedError(
        onRetry: _refreshAll,
      ),
      data: (state) {
        if (state.items.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _StoriesSection(
                    stories: stories,
                    onRetry: () => ref.invalidate(conquestStoriesProvider),
                    onOpen: (item) => context.push(
                      '${AppRoutes.conquests}/${item.post.id}',
                    ),
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Expanded(child: _EmptyFeed()),
                      if (state.hasMore)
                        _FeedFooter(
                          hasMore: true,
                          loading: state.isLoadingMore,
                          onLoadMore: _loadMore,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: _refreshAll,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            itemCount: state.items.length + 2,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _StoriesSection(
                  stories: stories,
                  onRetry: () => ref.invalidate(conquestStoriesProvider),
                  onOpen: (item) => context.push(
                    '${AppRoutes.conquests}/${item.post.id}',
                  ),
                );
              }
              if (index == state.items.length + 1) {
                return _FeedFooter(
                  hasMore: state.hasMore,
                  loading: state.isLoadingMore,
                  onLoadMore: _loadMore,
                );
              }
              final item = state.items[index - 1];
              final ownPost = currentUid == item.post.userId;
              return ConquestPostCard(
                item: item,
                useThumbnail: true,
                onTap: () => context.push(
                  '${AppRoutes.conquests}/${item.post.id}',
                ),
                onReaction: ownPost || _busyReactions.contains(item.post.id)
                    ? null
                    : (value) => _setReaction(item, value),
                onComments: () => _openComments(item),
                onMore: ownPost ? null : () => _showActions(item),
              );
            },
          ),
        );
      },
    );
  }
}

enum _FeedAction { report, block }

class _StoriesSection extends StatelessWidget {
  const _StoriesSection({
    required this.stories,
    required this.onOpen,
    required this.onRetry,
  });

  final AsyncValue<List<ConquestFeedItem>> stories;
  final ValueChanged<ConquestFeedItem> onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => stories.when(
        loading: () => const Padding(
          padding: EdgeInsets.fromLTRB(18, 12, 18, 8),
          child: Row(
            children: [
              Text('Historias'),
              SizedBox(width: 12),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 10, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'No se pudieron cargar las historias.',
                  style: AppTextStyles.caption,
                ),
              ),
              TextButton(onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
        data: (items) {
          if (items.isEmpty) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text('Historias', style: AppTextStyles.titleMedium),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 94,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) => _StoryTile(
                      item: items[index],
                      onTap: () => onOpen(items[index]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({required this.item, required this.onTap});

  final ConquestFeedItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = item.author.displayName.trim().isEmpty
        ? 'Corredor'
        : item.author.displayName.trim();
    final imageUrl = [
      item.post.thumbnailUrl,
      item.post.mediaUrl,
      item.author.photoUrl,
    ].whereType<String>().where((value) => value.isNotEmpty).firstOrNull;
    final initial = name[0].toUpperCase();

    return Semantics(
      button: true,
      label: 'Abrir historia de $name',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 72,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent, width: 2),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surfaceAlt,
                  foregroundImage: imageUrl == null
                      ? null
                      : CachedNetworkImageProvider(imageUrl),
                  onForegroundImageError: imageUrl == null ? null : (_, __) {},
                  child: Text(initial, style: AppTextStyles.titleMedium),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedFooter extends StatelessWidget {
  const _FeedFooter({
    required this.hasMore,
    required this.loading,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool loading;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Estás al día.',
          style: AppTextStyles.caption,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 8, 48, 20),
      child: OutlinedButton(
        onPressed: loading ? null : onLoadMore,
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Ver más'),
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.dynamic_feed_outlined,
                size: 52,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text('Todavía no hay conquistas',
                  style: AppTextStyles.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Las publicaciones públicas y las de tus conexiones '
                'aparecerán aquí.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No se pudo cargar el feed.',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
