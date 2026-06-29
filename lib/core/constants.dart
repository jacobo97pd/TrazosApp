abstract final class AppConstants {
  // Reglas de captura — deben coincidir con las constantes en functions/index.js
  static const double minRunDistanceMeters    = 500.0;
  static const double zoneOverlapThreshold    = 0.60; // 60 %
  static const int    zoneExpirationDays      = 7;
  static const int    minPolygonPoints        = 4;    // puntos únicos mínimos

  // GPS
  static const int    locationIntervalMs      = 2000;  // cada 2 s en carrera
  static const double locationMinDistanceM    = 5.0;   // filtro mínimo de movimiento
  static const double staleLocationSeconds    = 10.0;

  // Anti-trampas por velocidad (corriendo, no en bici/coche). Tunables.
  // Velocidad media de toda la carrera permitida para validar la captura.
  static const double maxAvgSpeedKmh          = 20.0;  // por encima ≈ bici/coche
  static const double minAvgSpeedKmh          = 2.0;   // por debajo ≈ parado/deriva GPS
  // Salto entre dos lecturas GPS imposible corriendo → se descarta (no suma km).
  static const double glitchSpeedKmh          = 35.0;

  // Puntuación / ranking — todas las zonas valen igual; el score combina
  // zonas conquistadas y km totales recorridos. Tunables.
  static const int    scorePerZone            = 100;   // 1 zona = 10 km de score
  static const double scorePerKm              = 10.0;

  // Mapa
  static const double defaultZoom             = 15.0;
  static const double runningZoom             = 16.5;

  // Strava — el Client ID es público (va en la URL OAuth). El Client Secret
  // NO se guarda en el cliente: vive como secreto en las Cloud Functions
  // (STRAVA_CLIENT_SECRET), que hacen el intercambio code→token de forma segura.
  static const String stravaClientId          = '255245';
  static const String stravaRedirectUri       =
      'https://trazos-database.web.app/strava-callback';
  static const String stravaCallbackHost      = 'trazos-database.web.app';
  static const String stravaCallbackPath      = '/strava-callback';
  static const String stravaScope             = 'read,activity:write,activity:read_all';

  // Deep-link scheme
  static const String appScheme               = 'runrace';

  // Shared prefs keys
  static const String prefOnboardingDone      = 'onboarding_done';
  static const String prefFcmToken            = 'fcm_token';
}
