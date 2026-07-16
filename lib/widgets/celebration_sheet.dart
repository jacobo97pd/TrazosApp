import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../progression/runner_progress.dart';
import 'star_rating.dart';

/// Muestra UNA sola celebración agrupada (XP + subida de nivel + logros).
Future<void> showCelebration(BuildContext context, CelebrationSummary c) {
  if (!c.hasSomething) return Future.value();
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).padding.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration_rounded,
              color: AppColors.gold, size: 44),
          const SizedBox(height: 12),
          Text('¡Reto completado!',
              style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          if (c.xpGained > 0) ...[
            const SizedBox(height: 6),
            Text('+${c.xpGained} XP',
                style: AppTextStyles.headlineLarge
                    .copyWith(color: AppColors.accent)),
          ],
          if (c.leveledUp) ...[
            const SizedBox(height: 12),
            Text('¡Nivel ${c.toLevel} alcanzado!',
                style: AppTextStyles.titleLarge),
            if (c.starChanged) ...[
              const SizedBox(height: 8),
              StarRating(stars: c.toStar.stars, size: 26),
              Text(c.toStar.label, style: AppTextStyles.caption),
            ],
          ],
          if (c.newAchievements.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),
            for (final a in c.newAchievements)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(a.icon, color: AppColors.gold),
                title: Text('Nuevo logro: ${a.name}',
                    style: AppTextStyles.bodyMedium),
                subtitle:
                    Text(a.description, style: AppTextStyles.caption),
              ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Genial'),
            ),
          ),
        ],
      ),
    ),
  );
}
