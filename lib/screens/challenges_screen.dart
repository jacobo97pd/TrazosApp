import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../progression/challenge.dart';
import '../progression/progression_config.dart';
import '../progression/progression_providers.dart';
import '../widgets/celebration_sheet.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challenges = ref.watch(challengeStatusesProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Retos')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: challenges.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _ChallengeCard(status: challenges[i]),
      ),
    );
  }
}

class _ChallengeCard extends ConsumerWidget {
  const _ChallengeCard({required this.status});
  final ChallengeStatus status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = status.challenge;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: status.claimed ? AppColors.green : AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(c.title, style: AppTextStyles.titleLarge),
              ),
              Text('+${_xp(c)} XP',
                  style: AppTextStyles.labelLarge
                      .copyWith(color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 4),
          Text(c.description, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: status.progress,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                  status.claimed ? AppColors.green : AppColors.accent),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${status.current.toStringAsFixed(0)} / ${c.target}',
                  style: AppTextStyles.caption),
              if (status.claimed)
                Text('Completado',
                    style: AppTextStyles.labelMedium
                        .copyWith(color: AppColors.green))
              else if (status.claimable)
                _ClaimButton(challengeId: c.id)
              else
                Text('En progreso', style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  int _xp(Challenge c) =>
      ((ProgressionConfig.xpByDifficulty[c.difficulty] ?? 0) *
              (ProgressionConfig.periodMultiplier[c.period] ?? 1.0))
          .round();
}

class _ClaimButton extends ConsumerStatefulWidget {
  const _ClaimButton({required this.challengeId});
  final String challengeId;

  @override
  ConsumerState<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends ConsumerState<_ClaimButton> {
  bool _busy = false;

  Future<void> _claim() async {
    setState(() => _busy = true);
    final out =
        await ref.read(progressionControllerProvider).claim(widget.challengeId);
    if (!mounted) return;
    setState(() => _busy = false);
    if (out != null && out.applied) {
      await showCelebration(context, out.celebration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _busy ? null : _claim,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 36),
        padding: const EdgeInsets.symmetric(horizontal: 16),
      ),
      child: _busy
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Text('Reclamar'),
    );
  }
}
