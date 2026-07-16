import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/challenge_experience_calculator.dart';
import 'package:runrace/progression/progression_config.dart';

void main() {
  const calc = ChallengeExperienceCalculator();

  test('XP base por dificultad (individual)', () {
    expect(calc.xpFor(difficulty: ChallengeDifficulty.veryEasy), 25);
    expect(calc.xpFor(difficulty: ChallengeDifficulty.easy), 50);
    expect(calc.xpFor(difficulty: ChallengeDifficulty.medium), 100);
    expect(calc.xpFor(difficulty: ChallengeDifficulty.hard), 200);
    expect(calc.xpFor(difficulty: ChallengeDifficulty.legendary), 500);
  });

  test('multiplicador por periodo', () {
    expect(
      calc.xpFor(
          difficulty: ChallengeDifficulty.medium,
          period: ChallengePeriod.weekly),
      120, // 100 * 1.2
    );
    expect(
      calc.xpFor(
          difficulty: ChallengeDifficulty.hard,
          period: ChallengePeriod.monthly),
      300, // 200 * 1.5
    );
    expect(
      calc.xpFor(
          difficulty: ChallengeDifficulty.legendary,
          period: ChallengePeriod.special),
      1000, // 500 * 2.0
    );
  });
}
