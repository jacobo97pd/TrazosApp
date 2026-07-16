import 'achievement.dart';
import 'progression_config.dart';

/// Reto: objetivo con recompensa de XP. Milestone sobre una métrica del corredor.
class Challenge {
  const Challenge({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.period,
    required this.metric,
    required this.target,
  });
  final String id; // estable
  final String title;
  final String description;
  final ChallengeDifficulty difficulty;
  final ChallengePeriod period;
  final AchievementMetric metric;
  final num target;
}

class ChallengeStatus {
  const ChallengeStatus({
    required this.challenge,
    required this.current,
    required this.claimed,
  });
  final Challenge challenge;
  final num current;
  final bool claimed; // ya reclamado (XP concedida)

  bool get met => current >= challenge.target;
  bool get claimable => met && !claimed;
  double get progress =>
      challenge.target == 0 ? 1 : (current / challenge.target).clamp(0.0, 1.0);
}

/// Catálogo central de retos (ids estables). Milestones sobre km acumulados.
const List<Challenge> kChallengesCatalog = [
  Challenge(
    id: 'ch.km_5',
    title: 'Primeros 5 km',
    description: 'Acumula 5 km corriendo.',
    difficulty: ChallengeDifficulty.easy,
    period: ChallengePeriod.individual,
    metric: AchievementMetric.totalKm,
    target: 5,
  ),
  Challenge(
    id: 'ch.km_20',
    title: 'Fondista',
    description: 'Acumula 20 km.',
    difficulty: ChallengeDifficulty.medium,
    period: ChallengePeriod.weekly,
    metric: AchievementMetric.totalKm,
    target: 20,
  ),
  Challenge(
    id: 'ch.km_50',
    title: 'Medio centenar',
    description: 'Acumula 50 km.',
    difficulty: ChallengeDifficulty.hard,
    period: ChallengePeriod.monthly,
    metric: AchievementMetric.totalKm,
    target: 50,
  ),
  Challenge(
    id: 'ch.km_100',
    title: 'Centurión',
    description: 'Acumula 100 km.',
    difficulty: ChallengeDifficulty.legendary,
    period: ChallengePeriod.special,
    metric: AchievementMetric.totalKm,
    target: 100,
  ),
];
