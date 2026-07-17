import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'conquest_media_service.dart';
import 'conquest_post.dart';
import 'conquest_post_repository.dart';
import 'story_service.dart';
import 'story_view_repository.dart';
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

// ── Publicaciones ─────────────────────────────────────────────────────────────
final conquestPostRepositoryProvider =
    Provider<ConquestPostRepository>((_) => FirestoreConquestPostRepository());

final conquestMediaServiceProvider =
    Provider<ConquestMediaService>((_) => ConquestMediaService());

// -- Historias -------------------------------------------------------------
final storyConfigProvider = Provider<StoryConfig>((_) => const StoryConfig());

final storyServiceProvider = Provider<StoryService>(
  (ref) => StoryService(config: ref.watch(storyConfigProvider)),
);

final storyExpirationServiceProvider =
    Provider<StoryExpirationService>((_) => const StoryExpirationService());

final storyViewRepositoryProvider = Provider<StoryViewRepository>(
  (_) => FirestoreStoryViewRepository(),
);

final myPostsProvider = StreamProvider.autoDispose<List<ConquestPost>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(conquestPostRepositoryProvider).watchForUser(uid);
});

// Fuerza una reevaluacion periodica aunque Firestore no emita cambios cuando
// una historia alcanza su fecha de caducidad.
final _storyClockProvider = StreamProvider.autoDispose<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

final myActiveStoriesProvider = Provider.autoDispose<List<ConquestPost>>((ref) {
  final posts = ref.watch(myPostsProvider).valueOrNull ?? const [];
  final now = ref.watch(_storyClockProvider).valueOrNull ?? DateTime.now();
  return ref.watch(storyExpirationServiceProvider).activeOnly(posts, now);
});

final storyViewsProvider =
    StreamProvider.autoDispose.family<List<StoryView>, String>((ref, storyId) {
  return ref.watch(storyViewRepositoryProvider).watchForStory(storyId);
});

final storyViewCountProvider = Provider.autoDispose.family<int, String>(
  (ref, storyId) =>
      ref.watch(storyViewsProvider(storyId)).valueOrNull?.length ?? 0,
);

// Nº de conquistas compartidas (con media/pública) para logros.
final sharedConquestsCountProvider = Provider.autoDispose<int>((ref) {
  final posts = ref.watch(myPostsProvider).valueOrNull ?? const [];
  return posts.where((p) => !p.isStory).length;
});

// Ciudades documentadas (distintas) para logros.
final citiesDocumentedProvider = Provider.autoDispose<int>((ref) {
  final conquests = ref.watch(myConquestsProvider).valueOrNull ?? const [];
  return conquests
      .map((c) => c.city.trim().toLowerCase())
      .where((c) => c.isNotEmpty)
      .toSet()
      .length;
});
