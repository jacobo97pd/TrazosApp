/// Resultado tolerante del parseo del nombre de equipamiento de Strava.
class ParsedShoeName {
  const ParsedShoeName(
      {this.brand, this.model, this.nickname, required this.raw});
  final String? brand;
  final String? model;
  final String? nickname;
  final String raw;
}

// Marcas conocidas (ampliable). NO se depende solo del nombre para identificar
// la marca: si no coincide, brand queda null y se conserva el texto crudo.
const _knownBrands = {
  'nike',
  'adidas',
  'asics',
  'brooks',
  'hoka',
  'saucony',
  'new balance',
  'newbalance',
  'mizuno',
  'puma',
  'salomon',
  'on',
  'altra',
  'reebok',
};

/// Parser tolerante: "Marca Modelo", "Marca Modelo (Apodo)", "Solo apodo",
/// texto incompleto o personalizado. Nunca falla; devuelve lo que puede.
class ShoeNameParser {
  const ShoeNameParser();

  ParsedShoeName parse(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return const ParsedShoeName(raw: '');

    // Apodo entre paréntesis.
    String? nickname;
    var body = text;
    final paren = RegExp(r'\(([^)]*)\)').firstMatch(text);
    if (paren != null) {
      nickname = paren.group(1)?.trim();
      body = text.replaceRange(paren.start, paren.end, '').trim();
    }

    final lower = body.toLowerCase();
    String? brand;
    // Marca de dos palabras (p. ej. "new balance") o de una.
    for (final b in _knownBrands) {
      if (lower == b || lower.startsWith('$b ')) {
        brand = body.substring(0, b.length).trim();
        body = body.substring(b.length).trim();
        break;
      }
    }

    // Sin marca conocida no adivinamos el modelo: el texto es apodo/personalizado.
    if (brand == null) {
      return ParsedShoeName(
          nickname: nickname ?? (body.isEmpty ? null : body), raw: text);
    }
    return ParsedShoeName(
        brand: brand,
        model: body.isEmpty ? null : body,
        nickname: nickname,
        raw: text);
  }
}
