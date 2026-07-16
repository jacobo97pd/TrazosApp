import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/runner_star_calculator.dart';

void main() {
  const calc = RunnerStarCalculator();

  test('rangos de estrellas por nivel', () {
    expect(calc.forLevel(1).stars, 1);
    expect(calc.forLevel(5).stars, 1);
    expect(calc.forLevel(6).stars, 2);
    expect(calc.forLevel(15).stars, 2);
    expect(calc.forLevel(16).stars, 3);
    expect(calc.forLevel(30).stars, 3);
    expect(calc.forLevel(31).stars, 4);
    expect(calc.forLevel(50).stars, 4);
    expect(calc.forLevel(51).stars, 5);
    expect(calc.forLevel(120).stars, 5);
  });

  test('etiquetas de categoría', () {
    expect(calc.forLevel(1).label, 'Principiante');
    expect(calc.forLevel(6).label, 'Constante');
    expect(calc.forLevel(16).label, 'Experimentado');
    expect(calc.forLevel(31).label, 'Avanzado');
    expect(calc.forLevel(51).label, 'Élite');
  });

  test('transición EXACTA entre categorías', () {
    // El último nivel de una categoría y el primero de la siguiente.
    expect(calc.forLevel(5), isNot(equals(calc.forLevel(6))));
    expect(calc.forLevel(15).stars, 2);
    expect(calc.forLevel(16).stars, 3);
  });
}
