/// Entrada mínima del directorio de corredores (decoplada de UserModel).
class RunnerDirectoryEntry {
  const RunnerDirectoryEntry({
    required this.uid,
    required this.stravaAthleteId,
    required this.stravaConnected,
    required this.discoverable,
  });
  final String uid;
  final String? stravaAthleteId;
  final bool stravaConnected;
  final bool discoverable;
}

/// Sugiere corredores de Trazos que "también usan Strava" (directorio opt-in).
/// NO importa amigos de Strava (la API no lo permite): solo lista usuarios de
/// Trazos con Strava conectado que han ACTIVADO el descubrimiento.
class StravaIdentityMatcher {
  const StravaIdentityMatcher();

  List<RunnerDirectoryEntry> suggestions({
    required String meUid,
    required bool meDiscoverable,
    required List<RunnerDirectoryEntry> candidates,
    Set<String> excludedUids = const {},
  }) {
    // Si yo no participo del descubrimiento, no propongo a nadie.
    if (!meDiscoverable) return const [];
    return [
      for (final c in candidates)
        if (c.uid != meUid &&
            c.discoverable &&
            c.stravaConnected &&
            (c.stravaAthleteId?.isNotEmpty ?? false) &&
            !excludedUids.contains(c.uid))
          c,
    ];
  }
}
