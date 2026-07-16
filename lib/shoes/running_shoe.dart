enum ShoeSource { strava, manual, merged }

enum ShoeStatus { active, rotation, review, retired, archived }

/// Par de zapatillas. Separa datos de Strava, calculados por Trazos y editados
/// a mano. El kilometraje sincronizado sale de las actividades (ver
/// ShoeDistanceCalculator); foto/notas/límite pueden ser locales.
class RunningShoe {
  const RunningShoe({
    required this.id,
    required this.userId,
    required this.source,
    this.stravaGearId,
    this.brand,
    this.model,
    this.nickname,
    this.photoUrl,
    this.colorDescription,
    this.purchaseDate,
    this.firstUseDate,
    this.retiredDate,
    this.initialDistanceMeters = 0,
    this.syncedDistanceMeters = 0,
    this.localDistanceMeters = 0,
    this.recommendedMaxDistanceMeters =
        800000, // 800 km por defecto (ajustable)
    this.surfaceType,
    this.usageType,
    this.status = ShoeStatus.active,
    this.notes,
    this.isPrimary = false,
    required this.createdAt,
    required this.updatedAt,
    this.lastSyncedAt,
  });

  final String id;
  final String userId;
  final ShoeSource source;
  final String? stravaGearId;
  final String? brand;
  final String? model;
  final String? nickname;
  final String? photoUrl;
  final String? colorDescription;
  final DateTime? purchaseDate;
  final DateTime? firstUseDate;
  final DateTime? retiredDate;

  final double initialDistanceMeters; // km previos declarados por el usuario
  final double syncedDistanceMeters; // recalculado desde actividades
  final double
      localDistanceMeters; // añadidos manualmente (carreras sin Strava)
  final double recommendedMaxDistanceMeters;

  final String? surfaceType;
  final String? usageType;
  final ShoeStatus status;
  final String? notes;
  final bool isPrimary;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastSyncedAt;

  double get totalDistanceMeters =>
      initialDistanceMeters + syncedDistanceMeters + localDistanceMeters;

  String get displayName {
    final bm = [brand, model].where((s) => (s ?? '').isNotEmpty).join(' ');
    if (bm.isNotEmpty) {
      return nickname?.isNotEmpty == true ? '$bm · $nickname' : bm;
    }
    return (nickname?.isNotEmpty == true) ? nickname! : 'Zapatillas';
  }

  RunningShoe copyWith({
    ShoeSource? source,
    String? brand,
    String? model,
    String? nickname,
    String? photoUrl,
    double? initialDistanceMeters,
    double? syncedDistanceMeters,
    double? localDistanceMeters,
    double? recommendedMaxDistanceMeters,
    ShoeStatus? status,
    String? notes,
    bool? isPrimary,
    DateTime? retiredDate,
    DateTime? updatedAt,
    DateTime? lastSyncedAt,
  }) =>
      RunningShoe(
        id: id,
        userId: userId,
        source: source ?? this.source,
        stravaGearId: stravaGearId,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        nickname: nickname ?? this.nickname,
        photoUrl: photoUrl ?? this.photoUrl,
        colorDescription: colorDescription,
        purchaseDate: purchaseDate,
        firstUseDate: firstUseDate,
        retiredDate: retiredDate ?? this.retiredDate,
        initialDistanceMeters:
            initialDistanceMeters ?? this.initialDistanceMeters,
        syncedDistanceMeters: syncedDistanceMeters ?? this.syncedDistanceMeters,
        localDistanceMeters: localDistanceMeters ?? this.localDistanceMeters,
        recommendedMaxDistanceMeters:
            recommendedMaxDistanceMeters ?? this.recommendedMaxDistanceMeters,
        surfaceType: surfaceType,
        usageType: usageType,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        isPrimary: isPrimary ?? this.isPrimary,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      );
}
