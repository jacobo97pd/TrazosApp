import 'achievement.dart';
import 'achievement_catalog.dart';

/// Evalúa los logros de un corredor contra sus métricas. Puro y testeable.
/// El desbloqueo es IDEMPOTENTE: un logro ya desbloqueado no se vuelve a
/// conceder (se respeta su fecha original).
class AchievementEngine {
  const AchievementEngine({this.catalog = kAchievementsCatalog});

  final List<Achievement> catalog;

  /// Estado (progreso + desbloqueo) de todos los logros para unas métricas.
  /// [unlockedAt] mapea id → fecha de desbloqueo ya persistida.
  List<AchievementStatus> evaluate(
    RunnerStats stats, {
    Map<String, DateTime> unlockedAt = const {},
  }) {
    return [
      for (final a in catalog)
        AchievementStatus(
          achievement: a,
          current: stats.valueOf(a.metric),
          unlockedAt: unlockedAt[a.id],
        ),
    ];
  }

  /// Logros cuyo criterio se cumple AHORA y que aún no estaban desbloqueados.
  /// No concede dos veces el mismo logro.
  List<Achievement> newlyUnlocked(
    RunnerStats stats,
    Set<String> alreadyUnlocked,
  ) {
    return [
      for (final a in catalog)
        if (!alreadyUnlocked.contains(a.id) &&
            stats.valueOf(a.metric) >= a.target)
          a,
    ];
  }
}
