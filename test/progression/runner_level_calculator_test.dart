import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/runner_level_calculator.dart';

void main() {
  // base=100, growth=50 → incrementos 100,150,200,250…
  // XP acumulada para alcanzar: L1=0, L2=100, L3=250, L4=450, L5=700, L6=1000.
  const calc = RunnerLevelCalculator();

  test('nivel 1 con 0 XP', () {
    final l = calc.fromTotalXp(0);
    expect(l.level, 1);
    expect(l.xpIntoLevel, 0);
    expect(l.xpForLevel, 100);
    expect(l.xpToNextLevel, 100);
    expect(l.progress, 0.0);
  });

  test('XP negativa se trata como 0', () {
    expect(calc.fromTotalXp(-500).level, 1);
  });

  test('justo por debajo del límite sigue en el nivel', () {
    final l = calc.fromTotalXp(99);
    expect(l.level, 1);
    expect(l.xpIntoLevel, 99);
    expect(l.xpToNextLevel, 1);
  });

  test('límite EXACTO sube de nivel', () {
    final l = calc.fromTotalXp(100);
    expect(l.level, 2);
    expect(l.xpIntoLevel, 0);
    expect(l.xpForLevel, 150); // incremento del nivel 2
  });

  test('límites acumulados de varios niveles', () {
    expect(calc.fromTotalXp(249).level, 2);
    expect(calc.fromTotalXp(250).level, 3);
    expect(calc.fromTotalXp(449).level, 3);
    expect(calc.fromTotalXp(450).level, 4);
    expect(calc.fromTotalXp(700).level, 5);
    expect(calc.fromTotalXp(1000).level, 6);
  });

  test('progreso dentro del nivel', () {
    final l = calc.fromTotalXp(175); // nivel 2, into 75 de 150
    expect(l.level, 2);
    expect(l.xpIntoLevel, 75);
    expect(l.progress, closeTo(0.5, 1e-9));
  });

  test('curva no lineal: cada nivel cuesta más', () {
    expect(calc.incrementForLevel(1), 100);
    expect(calc.incrementForLevel(2), 150);
    expect(calc.incrementForLevel(3), 200);
    expect(
      calc.incrementForLevel(2) > calc.incrementForLevel(1),
      isTrue,
    );
  });
}
