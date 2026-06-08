import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/theme.dart';
import '../models/user_model.dart';
import '../models/club_model.dart';

// TODO: mover queries a providers dedicados
final _soloRankingProvider = StreamProvider.autoDispose<List<UserModel>>((ref) {
  return FirebaseFirestore.instance
      .collection('users')
      .orderBy('capturedZones', descending: true)
      .limit(50)
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
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Container(
                decoration: BoxDecoration(
                  color:        AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'RunClubs'),
                    Tab(text: 'Solos'),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _ClubRankingTab(),
            _SoloRankingTab(),
          ],
        ),
      ),
    );
  }
}

class _ClubRankingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clubsAsync = ref.watch(_clubRankingProvider);
    return clubsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (clubs) => ListView.builder(
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   clubs.length,
        itemBuilder: (_, i) => _RankRow(
          rank:     i + 1,
          name:     clubs[i].name,
          subtitle: '${clubs[i].memberCount} corredores · ${clubs[i].city}',
          stat:     '${clubs[i].totalZones} zonas',
          statKm:   '${clubs[i].totalKm.toStringAsFixed(0)} km',
          avatarLabel: clubs[i].name.substring(0, 2).toUpperCase(),
          accentColor: AppColors.cyan,
        ),
      ),
    );
  }
}

class _SoloRankingTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(_soloRankingProvider);
    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      error:   (e, _) => Center(child: Text('Error: $e')),
      data:    (users) => ListView.builder(
        padding:     const EdgeInsets.symmetric(vertical: 12),
        itemCount:   users.length,
        itemBuilder: (_, i) => _RankRow(
          rank:     i + 1,
          name:     users[i].displayName,
          subtitle: '${users[i].totalKm.toStringAsFixed(0)} km totales',
          stat:     '${users[i].capturedZones.length} zonas',
          statKm:   'Nivel ${users[i].level}',
          avatarLabel: users[i].displayName.isNotEmpty
              ? users[i].displayName.substring(0, 2).toUpperCase()
              : '??',
          accentColor: AppColors.accent,
        ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.subtitle,
    required this.stat,
    required this.statKm,
    required this.avatarLabel,
    required this.accentColor,
  });

  final int    rank;
  final String name;
  final String subtitle;
  final String stat;
  final String statKm;
  final String avatarLabel;
  final Color  accentColor;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankColors = [AppColors.gold, AppColors.textSecondary, const Color(0xFFCD7F32)];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isTop3 ? rankColors[rank - 1].withValues(alpha: 0.4) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Rango
          SizedBox(
            width: 32,
            child: Text(
              '$rank',
              style: AppTextStyles.headlineMedium.copyWith(
                color: isTop3 ? rankColors[rank - 1] : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),

          // Avatar
          CircleAvatar(
            backgroundColor: accentColor.withValues(alpha: 0.15),
            radius: 22,
            child: Text(avatarLabel,
                style: AppTextStyles.labelLarge.copyWith(color: accentColor)),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),

          // Stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(stat,   style: AppTextStyles.labelLarge.copyWith(color: accentColor)),
              Text(statKm, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}
