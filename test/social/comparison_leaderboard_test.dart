// ignore_for_file: prefer_const_constructors
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/social/comparison.dart';
import 'package:runrace/social/social_leaderboard_service.dart';

void main() {
  group('ProfileComparator', () {
    const cmp = ProfileComparator();

    test('solo compara métricas que AMBOS autorizan', () {
      final a = ComparableStats({
        ComparisonMetric.km: 30,
        ComparisonMetric.level: 5,
        ComparisonMetric.elevation: 200, // b no lo autoriza
      });
      final b = ComparableStats({
        ComparisonMetric.km: 25,
        ComparisonMetric.level: 5,
        ComparisonMetric.elevation: null,
      });
      final rows = cmp.compare(a, b);
      final metrics = rows.map((r) => r.metric).toSet();
      expect(metrics, {ComparisonMetric.km, ComparisonMetric.level});
      expect(metrics, isNot(contains(ComparisonMetric.elevation)));
    });

    test('determina líder y empate', () {
      final rows = cmp.compare(
        ComparableStats({ComparisonMetric.km: 30, ComparisonMetric.level: 4}),
        ComparableStats({ComparisonMetric.km: 25, ComparisonMetric.level: 4}),
      );
      expect(rows.firstWhere((r) => r.metric == ComparisonMetric.km).leader,
          Leader.a);
      expect(rows.firstWhere((r) => r.metric == ComparisonMetric.level).leader,
          Leader.tie);
    });
  });

  group('TraceComparator', () {
    const tc = TraceComparator();

    test('conjuntos comunes, exclusivos y % de solape', () {
      final r = tc.compare({'s1', 's2', 's3'}, {'s2', 's3', 's4'});
      expect(r.both, {'s2', 's3'});
      expect(r.onlyA, {'s1'});
      expect(r.onlyB, {'s4'});
      expect(r.overlapPercent, closeTo(50, 1e-9)); // 2 de 4
    });

    test('sin datos → 0%', () {
      expect(tc.compare(<String>{}, <String>{}).overlapPercent, 0);
    });
  });

  group('SocialLeaderboardService', () {
    const svc = SocialLeaderboardService();

    LeaderboardCandidate c(String u, num v, {bool consent = true}) =>
        LeaderboardCandidate(uid: u, value: v, consent: consent);

    test('solo entran quienes consienten', () {
      final r = svc.rank([c('a', 10), c('b', 20, consent: false), c('x', 5)]);
      expect(r.map((e) => e.uid), ['a', 'x']);
    });

    test('empate = mismo rango (1,2,2,4) y marcado', () {
      final r = svc.rank([c('a', 30), c('b', 20), c('c', 20), c('d', 10)]);
      expect(r.map((e) => e.rank), [1, 2, 2, 4]);
      expect(r.firstWhere((e) => e.uid == 'b').tied, isTrue);
      expect(r.firstWhere((e) => e.uid == 'a').tied, isFalse);
    });

    test('vacío → sin ranking', () {
      expect(svc.rank(const []), isEmpty);
    });
  });
}
