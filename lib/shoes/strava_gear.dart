/// Zapatilla tal cual la da Strava (/athlete → shoes[]).
class StravaGear {
  const StravaGear({required this.id, required this.name, this.distanceMeters = 0});
  final String id;
  final String name;
  final double distanceMeters;
}

/// Actividad de carrera con su equipamiento asociado.
class StravaRunActivity {
  const StravaRunActivity({
    required this.id,
    required this.distanceMeters,
    this.gearId,
  });
  final String id;
  final double distanceMeters;
  final String? gearId;
}
