import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../conquest/conquest_feed.dart';
import '../conquest/conquest_interaction.dart';
import '../core/theme.dart';

class ConquestPostCard extends StatelessWidget {
  const ConquestPostCard({
    super.key,
    required this.item,
    this.onTap,
    this.onReaction,
    this.onComments,
    this.onMore,
    this.showActions = true,
    this.useThumbnail = false,
  });

  final ConquestFeedItem item;
  final VoidCallback? onTap;
  final ValueChanged<ReactionType?>? onReaction;
  final VoidCallback? onComments;
  final VoidCallback? onMore;
  final bool showActions;
  final bool useThumbnail;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
              child: Row(
                children: [
                  _AuthorAvatar(
                    name: item.author.displayName,
                    photoUrl: item.author.photoUrl,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.author.displayName,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          DateFormat('dd MMM · HH:mm').format(post.createdAt),
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  if (post.isStory) const _StoryBadge(),
                  if (post.isStory && onMore != null) const SizedBox(width: 2),
                  if (onMore != null)
                    IconButton(
                      onPressed: onMore,
                      tooltip: 'Más opciones',
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                ],
              ),
            ),
            if ((useThumbnail &&
                        post.thumbnailUrl != null &&
                        post.thumbnailUrl!.isNotEmpty
                    ? post.thumbnailUrl
                    : post.mediaUrl)
                case final mediaUrl?)
              if (mediaUrl.isNotEmpty)
                Semantics(
                  image: true,
                  label: 'Imagen de la conquista de ${item.author.displayName}',
                  child: CachedNetworkImage(
                    imageUrl: mediaUrl,
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const SizedBox(
                      height: 260,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => const SizedBox(
                      height: 160,
                      child: Center(
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: AppColors.textDisabled,
                        ),
                      ),
                    ),
                  ),
                ),
            if (post.caption.isNotEmpty ||
                post.zoneNameSnapshot.isNotEmpty ||
                post.distanceSnapshot > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (post.caption.isNotEmpty)
                      Text(post.caption, style: AppTextStyles.bodyMedium),
                    if (post.caption.isNotEmpty &&
                        (post.zoneNameSnapshot.isNotEmpty ||
                            post.distanceSnapshot > 0))
                      const SizedBox(height: 10),
                    _PostMetadata(item: item),
                  ],
                ),
              ),
            if (showActions)
              ConquestActionsRow(
                item: item,
                onReaction: onReaction,
                onComments: onComments,
              ),
          ],
        ),
      ),
    );
  }
}

class ConquestActionsRow extends StatelessWidget {
  const ConquestActionsRow({
    super.key,
    required this.item,
    this.onReaction,
    this.onComments,
  });

  final ConquestFeedItem item;
  final ValueChanged<ReactionType?>? onReaction;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: Row(
        children: [
          _ActionButton(
            icon: item.myReaction == ReactionType.like
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: '${post.likesCount}',
            selected: item.myReaction == ReactionType.like,
            isToggle: true,
            tooltip: 'Me gusta',
            onPressed: onReaction == null
                ? null
                : () => onReaction!(item.myReaction == ReactionType.like
                    ? null
                    : ReactionType.like),
          ),
          _ActionButton(
            icon: Icons.front_hand_rounded,
            label: '${post.applauseCount}',
            selected: item.myReaction == ReactionType.applause,
            isToggle: true,
            tooltip: 'Aplauso',
            onPressed: onReaction == null
                ? null
                : () => onReaction!(item.myReaction == ReactionType.applause
                    ? null
                    : ReactionType.applause),
          ),
          _ActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            label: '${post.commentsCount}',
            tooltip: 'Comentarios',
            onPressed: onComments,
          ),
          const Spacer(),
          if (post.zoneNameSnapshot.isNotEmpty)
            const Icon(
              Icons.location_on_outlined,
              size: 17,
              color: AppColors.textSecondary,
            ),
        ],
      ),
    );
  }
}

class _PostMetadata extends StatelessWidget {
  const _PostMetadata({required this.item});
  final ConquestFeedItem item;

  @override
  Widget build(BuildContext context) {
    final post = item.post;
    final parts = <String>[
      if (post.zoneNameSnapshot.isNotEmpty) post.zoneNameSnapshot,
      if (post.distanceSnapshot > 0)
        '${(post.distanceSnapshot / 1000).toStringAsFixed(1)} km',
      if (post.durationSnapshot > 0)
        '${(post.durationSnapshot / 60).round()} min',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(parts.join(' · '), style: AppTextStyles.caption);
  }
}

class _AuthorAvatar extends StatelessWidget {
  const _AuthorAvatar({required this.name, this.photoUrl});
  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'T' : name.trim()[0].toUpperCase();
    return Semantics(
      container: true,
      image: true,
      label: 'Avatar de $name',
      excludeSemantics: true,
      child: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.surfaceAlt,
        foregroundImage: photoUrl == null || photoUrl!.isEmpty
            ? null
            : NetworkImage(photoUrl!),
        child: Text(initial, style: AppTextStyles.titleMedium),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.selected = false,
    this.isToggle = false,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool selected;
  final bool isToggle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      toggled: isToggle ? selected : null,
      label: '$tooltip, $label',
      excludeSemantics: true,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(44, 44),
        ),
        icon: Icon(icon, size: 19, color: color),
        label: Text(label,
            style: AppTextStyles.labelMedium.copyWith(color: color)),
      ),
    );
  }
}

class _StoryBadge extends StatelessWidget {
  const _StoryBadge();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          'Historia',
          style: AppTextStyles.labelMedium.copyWith(color: AppColors.accent),
        ),
      );
}
