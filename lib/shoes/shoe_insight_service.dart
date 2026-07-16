/// Resumen de una zapatilla para generar sugerencias (datos ya calculados).
class ShoeInsightInput {
  const ShoeInsightInput({
    required this.totalKm,
    required this.limitKm,
    required this.percent,
    this.daysSinceLastUse,
    this.isMostUsed = false,
    this.alternatingWell = false,
  });
  final double totalKm;
  final double limitKm;
  final double percent;
  final int? daysSinceLastUse;
  final bool isMostUsed;
  final bool alternatingWell;
}

/// Genera sugerencias orientativas. No sugiere comprar nada ni muestra
/// publicidad. Mensajes en lenguaje deportivo, no de economía.
class ShoeInsightService {
  const ShoeInsightService();

  List<String> insights(ShoeInsightInput i) {
    final out = <String>[];
    final total = i.totalKm.round();

    if (i.percent >= 100) {
      out.add('Has superado el límite que configuraste ($total km).');
    } else if (i.limitKm > 0 && i.percent >= 80) {
      final left = (i.limitKm - i.totalKm).round();
      out.add('Te quedan aproximadamente $left km para el límite configurado.');
    }
    if (total >= 500) {
      out.add('Has recorrido $total km con estas zapatillas.');
    }
    if ((i.daysSinceLastUse ?? 0) >= 90) {
      final months = (i.daysSinceLastUse! / 30).floor();
      out.add('Llevas unos $months meses sin utilizar este modelo.');
    }
    if (i.isMostUsed) {
      out.add('Estas son tus zapatillas más utilizadas.');
    }
    if (i.alternatingWell) {
      out.add('Has alternado correctamente entre varios pares.');
    }
    if (i.percent >= 85 && i.percent < 100) {
      out.add('Conviene revisar la suela y la amortiguación.');
    }
    return out;
  }
}
