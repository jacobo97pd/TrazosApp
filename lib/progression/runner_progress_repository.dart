import 'runner_progress.dart';

/// Persistencia de la progresión (XP, nivel, logros e idempotencia).
/// Cubre el rol de `AchievementRepository`: los logros desbloqueados viven
/// dentro de [RunnerProgress]. La implementación real (Firestore) se engancha
/// encima sin acoplar la lógica pura.
abstract interface class RunnerProgressRepository {
  Future<RunnerProgress> load(String userId);
  Future<void> save(String userId, RunnerProgress progress);
}

/// Implementación en memoria (para tests y previsualización).
class InMemoryRunnerProgressRepository implements RunnerProgressRepository {
  final Map<String, RunnerProgress> _store = {};

  @override
  Future<RunnerProgress> load(String userId) async =>
      _store[userId] ?? const RunnerProgress();

  @override
  Future<void> save(String userId, RunnerProgress progress) async {
    _store[userId] = progress;
  }
}
