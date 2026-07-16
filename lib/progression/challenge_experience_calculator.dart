import 'progression_config.dart';

/// Calcula la XP que otorga un reto según su dificultad y su periodo/tipo.
/// Puro y testeable; los valores vienen de la config (ajustables).
class ChallengeExperienceCalculator {
  const ChallengeExperienceCalculator({
    this.xpByDifficulty = ProgressionConfig.xpByDifficulty,
    this.periodMultiplier = ProgressionConfig.periodMultiplier,
  });

  final Map<ChallengeDifficulty, int> xpByDifficulty;
  final Map<ChallengePeriod, double> periodMultiplier;

  int xpFor({
    required ChallengeDifficulty difficulty,
    ChallengePeriod period = ChallengePeriod.individual,
  }) {
    final base = xpByDifficulty[difficulty] ?? 0;
    final mult = periodMultiplier[period] ?? 1.0;
    return (base * mult).round();
  }
}
