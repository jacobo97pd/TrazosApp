enum WearStatus { nueva, buenEstado, usoAvanzado, revisar, sustitucion }

enum WearConfidence { low, medium, high }

class ShoeWearInput {
  const ShoeWearInput({
    required this.distanceMeters,
    required this.limitMeters,
    this.ageDays,
    this.weeklyMeters,
    this.userSetLimit = false,
    this.surface,
    this.now,
  });
  final double distanceMeters;
  final double limitMeters;
  final int? ageDays;
  final double? weeklyMeters; // media semanal de uso
  final bool userSetLimit; // límite configurado por el usuario (no el defecto)
  final String? surface;
  final DateTime? now;
}

class ShoeWearEstimate {
  const ShoeWearEstimate({
    required this.percent,
    required this.status,
    required this.message,
    required this.confidence,
    this.nextMilestoneMeters,
    this.approxLimitDate,
  });
  final double percent; // 0..>100
  final WearStatus status;
  final String message;
  final WearConfidence confidence;
  final double? nextMilestoneMeters;
  final DateTime? approxLimitDate;

  static const disclaimer =
      'Estimación orientativa basada en kilometraje y uso. '
      'Revisa físicamente tus zapatillas.';
}

/// Estima el desgaste SOLO a partir de kilometraje, antigüedad, frecuencia,
/// superficie y límite configurable. Nunca datos médicos/peso/biomecánica.
/// Nunca presenta baja confianza como conclusión definitiva.
class ShoeWearEstimator {
  const ShoeWearEstimator();

  ShoeWearEstimate estimate(ShoeWearInput i) {
    final dist = _clean(i.distanceMeters);
    final limit = _clean(i.limitMeters);

    if (limit <= 0) {
      return const ShoeWearEstimate(
        percent: 0,
        status: WearStatus.buenEstado,
        message: 'Configura un límite para estimar el desgaste.',
        confidence: WearConfidence.low,
      );
    }

    final percent = (dist / limit * 100).clamp(0, 999).toDouble();
    final status = _statusFor(percent);

    // Próximo hito: 50 %, 80 %, 100 % del límite por encima de la distancia.
    double? next;
    for (final f in const [0.5, 0.8, 1.0]) {
      final m = limit * f;
      if (m > dist) {
        next = m;
        break;
      }
    }

    // Fecha aproximada de llegar al límite según la media semanal.
    DateTime? date;
    final weekly = _clean(i.weeklyMeters ?? 0);
    if (weekly > 0 && dist < limit) {
      final days = ((limit - dist) / (weekly / 7)).ceil();
      date = (i.now ?? DateTime.now()).add(Duration(days: days));
    }

    return ShoeWearEstimate(
      percent: percent,
      status: status,
      message: _messageFor(status),
      confidence: _confidence(i, weekly),
      nextMilestoneMeters: next,
      approxLimitDate: date,
    );
  }

  WearStatus _statusFor(double p) {
    if (p >= 100) return WearStatus.sustitucion;
    if (p >= 85) return WearStatus.revisar;
    if (p >= 60) return WearStatus.usoAvanzado;
    if (p >= 25) return WearStatus.buenEstado;
    return WearStatus.nueva;
  }

  String _messageFor(WearStatus s) => switch (s) {
        WearStatus.nueva => 'Como nuevas.',
        WearStatus.buenEstado => 'En buen estado.',
        WearStatus.usoAvanzado => 'Uso avanzado.',
        WearStatus.revisar => 'Conviene revisar suela y amortiguación.',
        WearStatus.sustitucion =>
          'Has superado el límite: sustitución recomendada.',
      };

  // Más datos reales → más confianza. El límite por defecto o la falta de uso
  // bajan la confianza (y no debe presentarse como definitivo).
  WearConfidence _confidence(ShoeWearInput i, double weekly) {
    var score = 0;
    if (i.userSetLimit) score++;
    if ((i.ageDays ?? 0) > 0) score++;
    if (weekly > 0) score++;
    if (score >= 3) return WearConfidence.high;
    if (score >= 1) return WearConfidence.medium;
    return WearConfidence.low;
  }

  double _clean(double v) => (v.isNaN || v.isInfinite || v < 0) ? 0 : v;
}
