import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/club_model.dart';
import '../models/user_model.dart';

// Score combinado: todas las zonas valen igual; suma zonas y km recorridos.
int _scoreFor(int zones, double km) =>
    zones * AppConstants.scorePerZone + (km * AppConstants.scorePerKm).round();

// TODO: mover queries a providers dedicados
final _soloRankingProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      // Orden por km (campo numérico que todos tienen); el ranking final por
      // score combinado se calcula en cliente. orderBy sobre 'capturedZones'
      // (array) no ordena por cantidad — por eso usamos totalKm aquí.
      .orderBy('totalKm', descending: true)
      .limit(100)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => UserModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

final _clubRankingProvider = StreamProvider.autoDispose<List<ClubModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('clubs')
      .orderBy('totalZones', descending: true)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => ClubModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>))
          .toList());
});

class RankingScreen extends ConsumerWidget {
  const RankingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Ranking'),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(60),
            child: RankingTabs(),
          ),
        ),
        body: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0F1018),
                AppColors.background,
                AppColors.background,
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: TabBarView(
            children: [
              _ClubRankingTab(),
              _SoloRankingTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class RankingTabs extends StatelessWidget {
  const RankingTabs({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: TabBar(
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.26),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle: AppTextStyles.labelLarge,
          unselectedLabelStyle: AppTextStyles.labelLarge,
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.groups_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('RunClubs'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_run_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Solos'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClubRankingTab extends ConsumerWidget {
  const _ClubRankingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(_clubRankingProvider);

    return clubsAsync.when(
      loading: () => const RankingLoadingState(),
      error: (e, _) => _RankingErrorState(message: e.toString()),
      data: (clubs) {
        final entries = _sortEntries(clubs.map(_entryFromClub));
        return _RankingContent(entries: entries);
      },
    );
  }
}

class _SoloRankingTab extends ConsumerWidget {
  const _SoloRankingTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_soloRankingProvider);

    return usersAsync.when(
      loading: () => const RankingLoadingState(),
      error: (e, _) => _RankingErrorState(message: e.toString()),
      data: (users) {
        final entries = _sortEntries([
          ...users.map(_entryFromUser),
        ]);
        return _RankingContent(entries: entries);
      },
    );
  }
}

class _RankingContent extends StatelessWidget {
  const _RankingContent({required this.entries});

  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const RankingEmptyState();

    final podiumEntries = entries.take(3).toList();
    final restEntries = entries.skip(3).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: RankingPodium(entries: podiumEntries),
        ),
        SliverToBoxAdapter(
          child: _RankingSectionHeader(count: restEntries.length),
        ),
        if (restEntries.isEmpty)
          const SliverToBoxAdapter(child: _RankingTopOnlyState())
        else
          RankingList(entries: restEntries, startRank: 4),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class RankingPodium extends StatelessWidget {
  const RankingPodium({super.key, required this.entries});

  final List<RankingEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 370;
        final horizontalPadding = compact ? 10.0 : 16.0;
        final availableWidth = constraints.maxWidth - (horizontalPadding * 2);
        final second = entries.length > 1 ? entries[1] : null;
        final first = entries.first;
        final third = entries.length > 2 ? entries[2] : null;

        if (entries.length == 1) {
          final width = availableWidth < 248 ? availableWidth : 248.0;
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              8,
            ),
            child: Center(
              child: SizedBox(
                width: width,
                child: PodiumItem(
                  rank: 1,
                  entry: first,
                  medalColor: _RankPalette.gold,
                  height: compact ? 250 : 266,
                  isChampion: true,
                ),
              ),
            ),
          );
        }

        if (entries.length == 2) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              18,
              horizontalPadding,
              8,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: PodiumItem(
                    rank: 2,
                    entry: second!,
                    medalColor: _RankPalette.silver,
                    height: compact ? 190 : 204,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PodiumItem(
                    rank: 1,
                    entry: first,
                    medalColor: _RankPalette.gold,
                    height: compact ? 230 : 250,
                    isChampion: true,
                  ),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            18,
            horizontalPadding,
            8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: second == null
                    ? const SizedBox.shrink()
                    : PodiumItem(
                        rank: 2,
                        entry: second,
                        medalColor: _RankPalette.silver,
                        height: compact ? 188 : 202,
                      ),
              ),
              Expanded(
                child: PodiumItem(
                  rank: 1,
                  entry: first,
                  medalColor: _RankPalette.gold,
                  height: compact ? 226 : 246,
                  isChampion: true,
                ),
              ),
              Expanded(
                child: third == null
                    ? const SizedBox.shrink()
                    : PodiumItem(
                        rank: 3,
                        entry: third,
                        medalColor: _RankPalette.bronze,
                        height: compact ? 180 : 194,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class PodiumItem extends StatelessWidget {
  const PodiumItem({
    super.key,
    required this.rank,
    required this.entry,
    required this.medalColor,
    required this.height,
    this.isChampion = false,
  });

  final int rank;
  final RankingEntry entry;
  final Color medalColor;
  final double height;
  final bool isChampion;

  @override
  Widget build(BuildContext context) {
    final avatarRadius = isChampion ? 30.0 : 24.0;
    final baseHeight = isChampion ? 40.0 : 30.0;
    final bodyMinHeight = height - baseHeight;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(minHeight: bodyMinHeight),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.fromLTRB(8, isChampion ? 12 : 10, 8, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color.lerp(AppColors.surfaceAlt, medalColor, 0.08)!,
                  AppColors.surface,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: medalColor.withValues(alpha: isChampion ? 0.78 : 0.48),
                width: isChampion ? 1.4 : 1,
              ),
              boxShadow: isChampion
                  ? [
                      BoxShadow(
                        color: _RankPalette.gold.withValues(alpha: 0.28),
                        blurRadius: 34,
                        spreadRadius: -2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                _RankMedal(
                  rank: rank,
                  color: medalColor,
                  isChampion: isChampion,
                ),
                SizedBox(height: isChampion ? 10 : 8),
                _RankingAvatar(
                  entry: entry,
                  radius: avatarRadius,
                  color: medalColor,
                  borderWidth: isChampion ? 2.2 : 1.4,
                ),
                const SizedBox(height: 8),
                Text(
                  entry.name,
                  style: (isChampion
                          ? AppTextStyles.titleLarge
                          : AppTextStyles.labelLarge)
                      .copyWith(color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _PodiumStats(entry: entry, compact: !isChampion),
              ],
            ),
          ),
          Container(
            height: baseHeight,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  medalColor.withValues(alpha: isChampion ? 0.44 : 0.28),
                  medalColor.withValues(alpha: isChampion ? 0.18 : 0.12),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
              border: Border.all(color: medalColor.withValues(alpha: 0.32)),
            ),
            child: Text(
              '#$rank',
              style: AppTextStyles.headlineMedium.copyWith(
                color: medalColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RankingList extends StatelessWidget {
  const RankingList({
    super.key,
    required this.entries,
    required this.startRank,
  });

  final List<RankingEntry> entries;
  final int startRank;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: RankingListItem(
              rank: startRank + index,
              entry: entries[index],
            ),
          ),
          childCount: entries.length,
        ),
      ),
    );
  }
}

class RankingListItem extends StatelessWidget {
  const RankingListItem({
    super.key,
    required this.rank,
    required this.entry,
  });

  final int rank;
  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '#$rank',
              style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          _RankingAvatar(
            entry: entry,
            radius: 22,
            color: entry.accentColor,
            borderWidth: 1,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.name,
                        style: AppTextStyles.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (entry.trendIcon != null) ...[
                      const SizedBox(width: 6),
                      _TrendIndicator(
                        icon: entry.trendIcon!,
                        color: entry.trendColor ?? AppColors.textSecondary,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.subtitle,
                  style: AppTextStyles.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (entry.badge != null) ...[
                  const SizedBox(height: 6),
                  _EntryBadge(label: entry.badge!, color: entry.accentColor),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RankingStatsColumn(entry: entry),
        ],
      ),
    );
  }
}

class RankingEmptyState extends StatelessWidget {
  const RankingEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.34),
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.accent,
                size: 38,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Todavía no hay campeones',
              style: AppTextStyles.headlineLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Sal a correr y conquista tu primera zona.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class RankingLoadingState extends StatelessWidget {
  const RankingLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 22, 16, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: _PodiumSkeleton(height: 174)),
                SizedBox(width: 8),
                Expanded(child: _PodiumSkeleton(height: 214)),
                SizedBox(width: 8),
                Expanded(child: _PodiumSkeleton(height: 166)),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: _SkeletonBox(width: 156, height: 18),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _RankingRowSkeleton(),
              ),
              childCount: 5,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankingSectionHeader extends StatelessWidget {
  const _RankingSectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Resto del ranking',
              style: AppTextStyles.headlineMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              count == 1 ? '1 rival' : '$count rivales',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingTopOnlyState extends StatelessWidget {
  const _RankingTopOnlyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            color: AppColors.accent.withValues(alpha: 0.84),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'La batalla por el top 10 acaba de empezar.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankingErrorState extends StatelessWidget {
  const _RankingErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.gold,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              'No se pudo cargar el ranking',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _PodiumStats extends StatelessWidget {
  const _PodiumStats({required this.entry, required this.compact});

  final RankingEntry entry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 8 : 10,
      runSpacing: 6,
      children: [
        _MiniStat(
          icon: Icons.bolt_rounded,
          value: '${entry.score}',
          label: 'pts',
          color: AppColors.gold,
          compact: compact,
        ),
        _MiniStat(
          icon: Icons.map_rounded,
          value: '${entry.zones}',
          label: 'zonas',
          color: entry.accentColor,
          compact: compact,
        ),
        _MiniStat(
          icon: Icons.directions_run_rounded,
          value: _formatKm(entry.km),
          label: 'km',
          color: AppColors.green,
          compact: compact,
        ),
      ],
    );
  }
}

class _RankingStatsColumn extends StatelessWidget {
  const _RankingStatsColumn({required this.entry});

  final RankingEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _InlineStat(
          icon: Icons.bolt_rounded,
          label: '${entry.score}',
          suffix: 'pts',
          color: AppColors.gold,
        ),
        const SizedBox(height: 6),
        _InlineStat(
          icon: Icons.map_rounded,
          label: '${entry.zones}',
          suffix: 'zonas',
          color: entry.accentColor,
        ),
        const SizedBox(height: 6),
        _InlineStat(
          icon: Icons.directions_run_rounded,
          label: _formatKm(entry.km),
          suffix: 'km',
          color: AppColors.green,
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: compact ? 12 : 13),
          const SizedBox(width: 4),
          Text(
            value,
            style:
                AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.icon,
    required this.label,
    required this.suffix,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(color: color),
        ),
        const SizedBox(width: 3),
        Text(suffix, style: AppTextStyles.caption),
      ],
    );
  }
}

class _RankingAvatar extends StatelessWidget {
  const _RankingAvatar({
    required this.entry,
    required this.radius,
    required this.color,
    required this.borderWidth,
  });

  final RankingEntry entry;
  final double radius;
  final Color color;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final image = _avatarImage(entry.imageUrl);

    return Container(
      padding: EdgeInsets.all(borderWidth),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            color,
            color.withValues(alpha: 0.26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceAlt,
        backgroundImage: image,
        child: image == null
            ? Text(
                entry.initials,
                style: AppTextStyles.labelLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              )
            : null,
      ),
    );
  }
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({
    required this.rank,
    required this.color,
    required this.isChampion,
  });

  final int rank;
  final Color color;
  final bool isChampion;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isChampion ? 0.22 : 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isChampion ? Icons.emoji_events_rounded : Icons.stars_rounded,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '#$rank',
            style: AppTextStyles.labelLarge.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _TrendIndicator extends StatelessWidget {
  const _TrendIndicator({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class _EntryBadge extends StatelessWidget {
  const _EntryBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.24)),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(color: color),
        ),
      ),
    );
  }
}

class _RankingRowSkeleton extends StatelessWidget {
  const _RankingRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          _SkeletonBox(width: 34, height: 20),
          SizedBox(width: 12),
          _SkeletonCircle(size: 46),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(width: double.infinity, height: 14),
                SizedBox(height: 8),
                _SkeletonBox(width: 118, height: 10),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 62, height: 34),
        ],
      ),
    );
  }
}

class _PodiumSkeleton extends StatelessWidget {
  const _PodiumSkeleton({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _SkeletonCircle(size: 52),
          SizedBox(height: 12),
          _SkeletonBox(width: 72, height: 12),
          SizedBox(height: 8),
          _SkeletonBox(width: 56, height: 10),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt.withValues(alpha: 0.78),
        shape: BoxShape.circle,
      ),
    );
  }
}

class RankingEntry {
  const RankingEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.zones,
    required this.km,
    required this.score,
    required this.initials,
    required this.accentColor,
    this.imageUrl,
    this.badge,
    this.trendIcon,
    this.trendColor,
  });

  final String id;
  final String name;
  final String subtitle;
  final int zones;
  final double km;
  final int score;
  final String initials;
  final Color accentColor;
  final String? imageUrl;
  final String? badge;
  final IconData? trendIcon;
  final Color? trendColor;
}

abstract final class _RankPalette {
  static const gold = AppColors.gold;
  static const silver = Color(0xFFC8D0DA);
  static const bronze = Color(0xFFCD7F32);
}

RankingEntry _entryFromClub(ClubModel club) {
  final city = club.city.trim();
  final subtitle = city.isEmpty
      ? '${club.memberCount} corredores'
      : '$city · ${club.memberCount} corredores';

  return RankingEntry(
    id: club.id,
    name: club.name.trim().isEmpty ? 'RunClub' : club.name.trim(),
    subtitle: subtitle,
    zones: club.totalZones,
    km: club.totalKm,
    score: _scoreFor(club.totalZones, club.totalKm),
    initials: _initials(club.name),
    accentColor: AppColors.cyan,
    imageUrl: club.logoUrl,
  );
}

RankingEntry _entryFromUser(UserModel user) {
  final name =
      user.displayName.trim().isEmpty ? 'Runner' : user.displayName.trim();

  return RankingEntry(
    id: user.uid,
    name: name,
    subtitle: 'Nivel ${user.level}',
    zones: user.capturedZones.length,
    km: user.totalKm,
    score: _scoreFor(user.capturedZones.length, user.totalKm),
    initials: _initials(name),
    accentColor: AppColors.accent,
    imageUrl: user.photoUrl,
  );
}

List<RankingEntry> _sortEntries(Iterable<RankingEntry> entries) {
  final sorted = entries.toList();
  sorted.sort((a, b) {
    final score = b.score.compareTo(a.score); // ranking por score combinado
    if (score != 0) return score;
    final zones = b.zones.compareTo(a.zones);
    if (zones != 0) return zones;
    return b.km.compareTo(a.km);
  });
  return sorted;
}

String _initials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .toList();

  if (words.isEmpty) return '??';
  if (words.length == 1) {
    final word = words.first;
    return word.substring(0, word.length >= 2 ? 2 : 1).toUpperCase();
  }

  return '${words.first.substring(0, 1)}${words.last.substring(0, 1)}'
      .toUpperCase();
}

String _formatKm(double km) {
  if (km >= 100) return km.toStringAsFixed(0);
  if (km == km.roundToDouble()) return km.toStringAsFixed(0);
  return km.toStringAsFixed(1);
}

ImageProvider<Object>? _avatarImage(String? url) {
  final normalized = url?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  return NetworkImage(normalized);
}
