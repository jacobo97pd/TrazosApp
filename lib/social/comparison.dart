/// Métricas comparables (solo agregadas; nada de ubicación, médico o privado).
enum ComparisonMetric {
  km,
  activities,
  activeDays,
  elevation,
  newStreets,
  zonesExplored,
  challengesCompleted,
  xp,
  level,
  stars,
  cities,
  sharedAchievements,
}

/// Estadísticas autorizadas de un corredor. Un valor null = NO autorizado →
/// no se compara esa métrica (privacidad por diseño).
class ComparableStats {
  const ComparableStats(this.values);
  final Map<ComparisonMetric, num?> values;
  num? operator [](ComparisonMetric m) => values[m];
}

/// Fila de comparación: valor de cada uno y quién lidera (null = empate).
enum Leader { a, b, tie }

class ComparisonRow {
  const ComparisonRow(this.metric, this.a, this.b, this.leader);
  final ComparisonMetric metric;
  final num a;
  final num b;
  final Leader leader;
}

/// Compara dos corredores usando solo métricas que AMBOS han autorizado.
class ProfileComparator {
  const ProfileComparator();

  List<ComparisonRow> compare(ComparableStats a, ComparableStats b) {
    final rows = <ComparisonRow>[];
    for (final m in ComparisonMetric.values) {
      final va = a[m], vb = b[m];
      if (va == null || vb == null) continue; // uno no lo autoriza → se omite
      rows.add(ComparisonRow(
        m,
        va,
        vb,
        va > vb ? Leader.a : (vb > va ? Leader.b : Leader.tie),
      ));
    }
    return rows;
  }
}

/// Resultado de comparar trazos por conjuntos de claves ya procesadas y
/// protegidas (calles/zonas), sin rutas crudas ni inicios/finales privados.
class TraceComparison {
  const TraceComparison({
    required this.both,
    required this.onlyA,
    required this.onlyB,
    required this.overlapPercent,
  });
  final Set<String> both;
  final Set<String> onlyA;
  final Set<String> onlyB;
  final double overlapPercent; // 0..100 sobre la unión
}

class TraceComparator {
  const TraceComparator();

  TraceComparison compare(Set<String> a, Set<String> b) {
    final both = a.intersection(b);
    final union = a.union(b);
    return TraceComparison(
      both: both,
      onlyA: a.difference(b),
      onlyB: b.difference(a),
      overlapPercent: union.isEmpty ? 0 : both.length * 100 / union.length,
    );
  }
}
