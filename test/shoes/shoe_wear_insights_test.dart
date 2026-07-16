import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/progression/achievement.dart';
import 'package:runrace/progression/achievement_engine.dart';
import 'package:runrace/shoes/shoe_insight_service.dart';
import 'package:runrace/shoes/shoe_stats_aggregator.dart';
import 'package:runrace/shoes/shoe_wear_estimator.dart';

void main() {
  group('ShoeWearEstimator', () {
    const est = ShoeWearEstimator();

    test('estados por porcentaje', () {
      WearStatus s(double km) => est
          .estimate(
              ShoeWearInput(distanceMeters: km * 1000, limitMeters: 800000))
          .status;
      expect(s(100), WearStatus.nueva); // 12.5%
      expect(s(300), WearStatus.buenEstado); // 37.5%
      expect(s(560), WearStatus.usoAvanzado); // 70%
      expect(s(720), WearStatus.revisar); // 90%
      expect(s(850), WearStatus.sustitucion); // >100%
    });

    test('límite 0 → confianza baja y sin porcentaje', () {
      final e = est.estimate(
          const ShoeWearInput(distanceMeters: 100000, limitMeters: 0));
      expect(e.percent, 0);
      expect(e.confidence, WearConfidence.low);
    });

    test('NaN/negativos no rompen', () {
      final e = est.estimate(const ShoeWearInput(
          distanceMeters: double.nan, limitMeters: double.infinity));
      expect(e.confidence, WearConfidence.low); // limit inválido → 0
    });

    test('confianza alta con límite propio + antigüedad + uso', () {
      final e = est.estimate(ShoeWearInput(
        distanceMeters: 400000,
        limitMeters: 800000,
        userSetLimit: true,
        ageDays: 200,
        weeklyMeters: 40000,
        now: DateTime(2026, 1, 1),
      ));
      expect(e.confidence, WearConfidence.high);
      expect(e.approxLimitDate, isNotNull); // hay fecha estimada
      expect(e.nextMilestoneMeters, 640000); // 80% de 800k
    });
  });

  group('ShoeInsightService', () {
    const svc = ShoeInsightService();

    test('supera el límite', () {
      final out = svc.insights(
          const ShoeInsightInput(totalKm: 850, limitKm: 800, percent: 106));
      expect(out.first, contains('superado el límite'));
    });

    test('km restantes cerca del límite', () {
      final out = svc.insights(
          const ShoeInsightInput(totalKm: 700, limitKm: 800, percent: 87.5));
      expect(out.any((m) => m.contains('100 km para el límite')), isTrue);
    });

    test('meses sin usar', () {
      final out = svc.insights(const ShoeInsightInput(
          totalKm: 50, limitKm: 800, percent: 6, daysSinceLastUse: 100));
      expect(out.any((m) => m.contains('meses sin utilizar')), isTrue);
    });
  });

  group('ShoeStatsAggregator', () {
    const agg = ShoeStatsAggregator();

    test('km por marca y modelo', () {
      final r = agg.aggregate(const [
        ShoeStatEntry(brand: 'Nike', model: 'Pegasus', km: 100, activities: 10),
        ShoeStatEntry(brand: 'Nike', model: 'Vomero', km: 50, activities: 5),
        ShoeStatEntry(brand: '', model: '', km: 20, activities: 2),
      ]);
      expect(r.kmByBrand['Nike'], 150);
      expect(r.kmByModel['Nike Pegasus'], 100);
      expect(r.kmByBrand['Sin marca'], 20);
      expect(r.activitiesByBrand['Nike'], 15);
    });
  });

  group('Logros de zapatillas (integrados)', () {
    const engine = AchievementEngine();

    test('primer par y 100 km con un par', () {
      final ids = engine.newlyUnlocked(
          const RunnerStats(shoesRegistered: 1, singleShoeMaxKm: 120),
          {}).map((a) => a.id);
      expect(ids, containsAll(['shoes.first', 'shoes.km_100']));
    });

    test('3 en rotación y 1000 km totales', () {
      final ids = engine.newlyUnlocked(
          const RunnerStats(shoesInRotation: 3, totalShoeKm: 1000),
          {}).map((a) => a.id);
      expect(ids, containsAll(['shoes.rotation_3', 'shoes.total_1000']));
    });
  });
}
