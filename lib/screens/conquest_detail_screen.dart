import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../conquest/conquest_feed.dart';
import '../conquest/conquest_feed_providers.dart';
import '../conquest/conquest_interaction.dart';
import '../conquest/conquest_interaction_providers.dart';
import '../conquest/conquest_providers.dart';
import '../core/theme.dart';
import '../core/router.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/conquest_comments_sheet.dart';
import '../widgets/conquest_post_card.dart';
import '../widgets/conquest_report_sheet.dart';

class ConquestDetailScreen extends ConsumerStatefulWidget {
  const ConquestDetailScreen({super.key, required this.postId});

  final String postId;

  @override
  ConsumerState<ConquestDetailScreen> createState() =>
      _ConquestDetailScreenState();
}

class _ConquestDetailScreenState extends ConsumerState<ConquestDetailScreen> {
  bool _reactionBusy = false;
  bool _tracked = false;

  Future<void> _handleLoaded(ConquestFeedItem item) async {
    if (_tracked) return;
    _tracked = true;
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    final ownPost = uid == item.post.userId;
    logAnalyticsBestEffort(
      () => ref.read(analyticsServiceProvider).logDetailView(ownPost: ownPost),
    );
    if (!ownPost && uid != null && item.post.isStory) {
      try {
        await ref.read(storyViewRepositoryProvider).recordView(
              storyId: item.post.id,
              viewerId: uid,
            );
      } catch (_) {
        // La vista no debe impedir abrir la historia si ya caducó entre medias.
      }
    }
  }

  Future<void> _setReaction(
    ConquestFeedItem item,
    ReactionType? reaction,
  ) async {
    if (_reactionBusy) return;
    setState(() => _reactionBusy = true);
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
      ref.invalidate(myConquestReactionProvider(item.post.id));
      ref.invalidate(conquestDetailProvider(item.post.id));
    } catch (_) {
      _show('No se pudo actualizar la reacción.');
    } finally {
      if (mounted) setState(() => _reactionBusy = false);
    }
  }

  Future<void> _openComments(ConquestFeedItem item) async {
    await showConquestCommentsSheet(
      context,
      postId: item.post.id,
      postOwnerId: item.post.userId,
      onChanged: () {
        ref.invalidate(conquestDetailProvider(item.post.id));
        ref.read(conquestFeedProvider.notifier).refresh();
      },
    );
  }

  Future<void> _showActions(ConquestFeedItem item) async {
    final action = await showModalBottomSheet<_PostAction>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('Reportar publicación'),
              onTap: () => Navigator.pop(context, _PostAction.report),
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded),
              title: Text('Bloquear a ${item.author.displayName}'),
              onTap: () => Navigator.pop(context, _PostAction.block),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PostAction.report:
        final report = await showConquestReportSheet(
          context,
          postId: item.post.id,
        );
        if (!mounted || report == null) break;
        if (item.post.isStory) ref.invalidate(conquestStoriesProvider);
        if (report.moderationStatus != ConquestModerationStatus.ok) {
          ref.invalidate(conquestFeedProvider);
          ref.invalidate(conquestDetailProvider(item.post.id));
        }
        _show(
          report.created
              ? 'Gracias. Revisaremos esta publicación.'
              : 'Ya habías reportado esta publicación.',
        );
        break;
      case _PostAction.block:
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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(conquestInteractionControllerProvider)
          .blockRunner(item.post.userId);
      logAnalyticsBestEffort(
        () => ref.read(analyticsServiceProvider).logRunnerBlocked(),
      );
      ref.invalidate(conquestFeedProvider);
      ref.invalidate(conquestStoriesProvider);
      ref.invalidate(blockedRunnerIdsProvider);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.board);
      }
      messenger.showSnackBar(
        SnackBar(
            content: Text('${item.author.displayName} ha sido bloqueado.')),
      );
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
    final detail = ref.watch(conquestDetailProvider(widget.postId));
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Conquista')),
      body: detail.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (_, __) => _Unavailable(
          onRetry: () => ref.invalidate(conquestDetailProvider(widget.postId)),
        ),
        data: (serverItem) {
          Future.microtask(() => _handleLoaded(serverItem));
          final reactionAsync =
              ref.watch(myConquestReactionProvider(serverItem.post.id));
          final reaction = reactionAsync.valueOrNull;
          final item = reactionAsync.hasValue
              ? serverItem.copyWith(
                  myReaction: reaction,
                  clearReaction: reaction == null,
                )
              : serverItem;
          final ownPost = uid == item.post.userId;
          return ListView(
            padding: const EdgeInsets.only(top: 10, bottom: 24),
            children: [
              ConquestPostCard(
                item: item,
                onReaction: ownPost || _reactionBusy
                    ? null
                    : (value) => _setReaction(item, value),
                onComments: () => _openComments(item),
                onMore: ownPost ? null : () => _showActions(item),
              ),
              if (ownPost && item.post.moderationStatus != 'ok')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Moderación: ${item.post.moderationStatus}',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.gold),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

enum _PostAction { report, block }

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_off_outlined,
                size: 48,
                color: AppColors.textDisabled,
              ),
              const SizedBox(height: 12),
              Text(
                'Esta conquista ya no está disponible.',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                  onPressed: onRetry, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
}
