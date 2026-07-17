import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../services/strava_service.dart';
import 'running_shoe.dart';
import 'shoe_repository.dart';
import 'shoe_sync_service.dart';

final shoeRepositoryProvider =
    Provider<ShoeRepository>((_) => FirestoreShoeRepository());

// Zapatillas del usuario en vivo.
final shoesProvider = StreamProvider.autoDispose<List<RunningShoe>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(shoeRepositoryProvider).watch(uid);
});

final shoeSyncControllerProvider = Provider((ref) => ShoeSyncController(ref));

class ShoeSyncController {
  ShoeSyncController(this.ref);
  final Ref ref;

  /// Sincroniza zapatillas y kilometraje desde Strava (idempotente). Devuelve
  /// el nº de zapatillas actualizadas, o -1 si no hay sesión de Strava/datos.
  Future<int> sync() async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return -1;

    final strava = ref.read(stravaServiceProvider);
    final repo = ref.read(shoeRepositoryProvider);

    final gears = await strava.fetchShoes();
    final activities = await strava.fetchRunActivities();
    if (gears.isEmpty && activities.isEmpty) return -1; // sin permisos/datos

    final existingShoes = await repo.shoesForUser(uid);
    final existingLinks = await repo.linksForUser(uid);

    final plan = const ShoeSyncService().plan(
      userId: uid,
      gears: gears,
      activities: activities,
      existingShoes: existingShoes,
      existingLinks: existingLinks,
      now: DateTime.now(),
    );

    for (final l in plan.links) {
      await repo.saveLink(l);
    }
    for (final s in plan.shoes) {
      await repo.save(s);
    }
    return plan.shoes.length;
  }
}
