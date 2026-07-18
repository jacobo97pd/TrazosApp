import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../conquest/conquest_feed_providers.dart';
import '../core/theme.dart';
import '../models/announcement_model.dart';
import '../providers/announcements_provider.dart';
import '../providers/events_provider.dart';
import '../widgets/event_card.dart';
import 'conquest_feed_view.dart';
import 'create_post_sheet.dart';

class BoardScreen extends ConsumerWidget {
  const BoardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Comunidad'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Conquistas'),
                Tab(text: 'Tablón'),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.accent,
            icon: const Icon(Icons.add_a_photo_outlined),
            label: const Text('Publicar'),
            onPressed: () async {
              await showCreatePostSheet(
                context,
                const ConquestContext(zoneName: 'tu recorrido'),
              );
              ref.invalidate(conquestFeedProvider);
              ref.invalidate(conquestStoriesProvider);
            },
          ),
          body: const TabBarView(
            children: [
              ConquestFeedView(),
              _BoardContent(),
            ],
          ),
        ),
      );
}

class _BoardContent extends ConsumerWidget {
  const _BoardContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final annAsync = ref.watch(announcementsProvider);
    final evAsync = ref.watch(publicEventsProvider);

    return annAsync.when(
      loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent)),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (announcements) {
        // Solo eventos públicos futuros
        final events =
            (evAsync.valueOrNull ?? []).where((e) => !e.isPast).toList();

        if (announcements.isEmpty && events.isEmpty) {
          return const _EmptyBoard();
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (events.isNotEmpty) ...[
              const _SectionHeader(
                title: 'Eventos abiertos',
                subtitle: 'Apúntate, tengas club o no',
              ),
              ...events.map((e) => EventCard(event: e, showClubName: true)),
              const SizedBox(height: 12),
            ],
            if (announcements.isNotEmpty) ...[
              const _SectionHeader(title: 'Anuncios'),
              ...announcements.map((a) => _AnnouncementCard(item: a)),
            ],
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headlineMedium),
          if (subtitle != null) Text(subtitle!, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.campaign_rounded,
                size: 48, color: AppColors.textDisabled),
            const SizedBox(height: 12),
            Text('No hay anuncios todavía',
                style: AppTextStyles.titleMedium, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(
                'Aquí aparecerán novedades, ganadores y los mejores run clubs.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  const _AnnouncementCard({required this.item});
  final AnnouncementModel item;

  ({IconData icon, Color color, String label}) get _meta => switch (item.type) {
        AnnouncementType.ganador => (
            icon: Icons.emoji_events_rounded,
            color: AppColors.gold,
            label: 'Ganador'
          ),
        AnnouncementType.club => (
            icon: Icons.groups_rounded,
            color: AppColors.cyan,
            label: 'Club'
          ),
        AnnouncementType.evento => (
            icon: Icons.event_rounded,
            color: AppColors.accent,
            label: 'Evento'
          ),
        AnnouncementType.aviso => (
            icon: Icons.campaign_rounded,
            color: AppColors.textSecondary,
            label: 'Aviso'
          ),
      };

  @override
  Widget build(BuildContext context) {
    final m = _meta;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              item.pinned ? m.color.withValues(alpha: 0.5) : AppColors.border,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            Image.network(
              item.imageUrl!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TypeBadge(icon: m.icon, color: m.color, label: m.label),
                    if (item.pinned) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.push_pin_rounded,
                          size: 14, color: AppColors.textSecondary),
                    ],
                    const Spacer(),
                    if (item.createdAt != null)
                      Text(DateFormat('dd MMM').format(item.createdAt!),
                          style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 10),
                Text(item.title, style: AppTextStyles.titleLarge),
                if (item.body.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.body,
                      style: AppTextStyles.bodyMedium
                          .copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: AppTextStyles.labelMedium
                  .copyWith(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
