import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../shoes/running_shoe.dart';
import '../shoes/shoe_providers.dart';
import '../shoes/shoe_wear_estimator.dart';

class ShoesScreen extends ConsumerWidget {
  const ShoesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shoesAsync = ref.watch(shoesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mis zapatillas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync_rounded),
            tooltip: 'Sincronizar con Strava',
            onPressed: () => _sync(context, ref),
          ),
        ],
      ),
      body: shoesAsync.when(
        loading: () => const _ShoeSkeleton(),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (shoes) => shoes.isEmpty
            ? _Empty(onSync: () => _sync(context, ref))
            : _ShoeList(shoes: shoes),
      ),
    );
  }

  Future<void> _sync(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        const SnackBar(content: Text('Sincronizando con Strava…')));
    final n = await ref.read(shoeSyncControllerProvider).sync();
    messenger.showSnackBar(SnackBar(
      content: Text(n < 0
          ? 'Conecta Strava y autoriza el acceso para importar zapatillas.'
          : 'Zapatillas sincronizadas.'),
    ));
  }
}

class _ShoeList extends StatelessWidget {
  const _ShoeList({required this.shoes});
  final List<RunningShoe> shoes;

  @override
  Widget build(BuildContext context) {
    final active = shoes.where((s) => s.status != ShoeStatus.retired).toList();
    final totalKm =
        shoes.fold<double>(0, (s, e) => s + e.totalDistanceMeters) / 1000;
    RunningShoe? main;
    for (final s in active) {
      if (s.isPrimary) main = s;
    }
    main ??= active.isNotEmpty ? active.first : null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Resumen
        Row(
          children: [
            Expanded(child: _Summary('Pares activos', '${active.length}')),
            const SizedBox(width: 12),
            Expanded(child: _Summary('Km totales', totalKm.toStringAsFixed(0))),
            const SizedBox(width: 12),
            Expanded(
                child: _Summary('Principal', (main?.displayName ?? '—'),
                    small: true)),
          ],
        ),
        const SizedBox(height: 16),
        for (final s in shoes) _ShoeCard(shoe: s),
      ],
    );
  }
}

class _ShoeCard extends StatelessWidget {
  const _ShoeCard({required this.shoe});
  final RunningShoe shoe;

  @override
  Widget build(BuildContext context) {
    final wear = const ShoeWearEstimator().estimate(ShoeWearInput(
      distanceMeters: shoe.totalDistanceMeters,
      limitMeters: shoe.recommendedMaxDistanceMeters,
    ));
    final km = (shoe.totalDistanceMeters / 1000).toStringAsFixed(0);
    final pct = (wear.percent / 100).clamp(0.0, 1.0);
    final color = wear.percent >= 100
        ? AppColors.accent
        : wear.percent >= 85
            ? AppColors.gold
            : AppColors.green;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child:
                      Text(shoe.displayName, style: AppTextStyles.titleLarge)),
              Text('$km km',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.textPrimary)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(wear.message, style: AppTextStyles.caption),
              Text(
                shoe.source == ShoeSource.strava ? 'Strava' : 'Trazos',
                style: AppTextStyles.caption,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary(this.label, this.value, {this.small = false});
  final String label;
  final String value;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: small
                  ? AppTextStyles.titleMedium
                  : AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(label,
              style: AppTextStyles.statLabel, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onSync});
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.directions_walk_rounded,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            Text('Aún no tienes zapatillas',
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Importa tus zapatillas y su kilometraje desde Strava.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onSync,
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Sincronizar con Strava'),
            ),
            const SizedBox(height: 12),
            Text(ShoeWearEstimate.disclaimer,
                style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ShoeSkeleton extends StatelessWidget {
  const _ShoeSkeleton();
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 96,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
            ),
        ],
      );
}
