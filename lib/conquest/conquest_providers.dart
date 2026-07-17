import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'zone_conquest.dart';
import 'zone_conquest_repository.dart';

final zoneConquestRepositoryProvider =
    Provider<ZoneConquestRepository>((_) => FirestoreZoneConquestRepository());

// Conquistas del usuario actual (para "Mis conquistas" y el contador de perfil).
final myConquestsProvider =
    StreamProvider.autoDispose<List<ZoneConquest>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(zoneConquestRepositoryProvider).watchForUser(uid);
});

final conquestCountProvider = Provider.autoDispose<int>(
    (ref) => ref.watch(myConquestsProvider).valueOrNull?.length ?? 0);
