import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/shoes/shoe_activity_link.dart';
import 'package:runrace/shoes/shoe_distance_calculator.dart';
import 'package:runrace/shoes/shoe_name_parser.dart';

void main() {
  const calc = ShoeDistanceCalculator();

  ShoeActivityLink link(String act, String shoe, double m,
          {String user = 'u'}) =>
      ShoeActivityLink(
          userId: user,
          activityId: act,
          shoeId: shoe,
          distanceMeters: m,
          source: 'strava');

  group('ShoeDistanceCalculator', () {
    test('suma actividades de la zapatilla', () {
      final links = [link('a1', 's1', 5000), link('a2', 's1', 3000)];
      expect(calc.syncedMetersFor('s1', links), 8000);
    });

    test('idempotente: actividad duplicada no suma dos veces', () {
      final links = [link('a1', 's1', 5000), link('a1', 's1', 5000)];
      expect(calc.syncedMetersFor('s1', links), 5000);
    });

    test('total = inicial + sincronizado + local', () {
      final links = [link('a1', 's1', 10000)];
      final total = calc.totalMetersFor(
          shoeId: 's1', initialMeters: 2000, localMeters: 1000, links: links);
      expect(total, 13000);
    });

    test('reconstrucción: quitar una actividad baja el total', () {
      var links = [link('a1', 's1', 5000), link('a2', 's1', 3000)];
      expect(calc.syncedMetersFor('s1', links), 8000);
      links = [link('a1', 's1', 5000)]; // a2 eliminada
      expect(calc.syncedMetersFor('s1', links), 5000);
    });

    test('actualizar distancia de una actividad recalcula', () {
      final links = [link('a1', 's1', 5000).copyWith(distanceMeters: 6000)];
      expect(calc.syncedMetersFor('s1', links), 6000);
    });

    test('cambiar de zapatilla mueve los km', () {
      final moved = link('a1', 's1', 5000).copyWith(shoeId: 's2');
      expect(calc.syncedMetersFor('s1', [moved]), 0);
      expect(calc.syncedMetersFor('s2', [moved]), 5000);
    });

    test('límite 0, negativos, NaN e Infinity no rompen', () {
      final links = [
        link('a1', 's1', -100),
        link('a2', 's1', double.nan),
        link('a3', 's1', double.infinity),
        link('a4', 's1', 4000),
      ];
      expect(calc.syncedMetersFor('s1', links), 4000);
      expect(
          calc.totalMetersFor(
              shoeId: 's1',
              initialMeters: double.nan,
              localMeters: -50,
              links: links),
          4000);
    });

    test('actividad sin zapatilla no cuenta', () {
      final links = [link('a1', '', 5000), link('a2', 'unassigned', 3000)];
      expect(calc.syncedMetersFor('s1', links), 0);
    });
  });

  group('ShoeNameParser', () {
    const p = ShoeNameParser();

    test('marca + modelo', () {
      final r = p.parse('Nike Pegasus 40');
      expect(r.brand, 'Nike');
      expect(r.model, 'Pegasus 40');
    });

    test('marca de dos palabras', () {
      final r = p.parse('New Balance 1080');
      expect(r.brand, 'New Balance');
      expect(r.model, '1080');
    });

    test('marca + modelo + apodo', () {
      final r = p.parse('Asics Nimbus (Rojas)');
      expect(r.brand, 'Asics');
      expect(r.model, 'Nimbus');
      expect(r.nickname, 'Rojas');
    });

    test('solo apodo / personalizado', () {
      final r = p.parse('Las viejas');
      expect(r.brand, isNull);
      expect(r.nickname, 'Las viejas');
    });

    test('vacío no rompe', () {
      expect(p.parse(null).raw, '');
      expect(p.parse('   ').brand, isNull);
    });
  });
}
