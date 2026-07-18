import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import 'runner_connection.dart';
import 'runner_connection_repository.dart';
import 'runner_connection_service.dart';
import 'social_privacy.dart';
import 'strava_identity_matcher.dart';

const _svc = RunnerConnectionService();

final connectionRepositoryProvider = Provider<RunnerConnectionRepository>(
    (_) => FirestoreRunnerConnectionRepository());

final myConnectionsProvider =
    StreamProvider.autoDispose<List<RunnerConnection>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const []);
  return ref.watch(connectionRepositoryProvider).watchForUser(uid);
});

final socialPrivacyProvider = StreamProvider.autoDispose<SocialPrivacy>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(const SocialPrivacy());
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((s) =>
          SocialPrivacy.fromMap(s.data()?['social'] as Map<String, dynamic>?));
});

// Perfil mínimo de otro corredor (nombre/foto) para pintar tarjetas.
final userModelProvider =
    FutureProvider.autoDispose.family<UserModel?, String>((ref, uid) async {
  final s = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .withConverter<UserModel>(
        fromFirestore: (d, _) => UserModel.fromFirestore(d),
        toFirestore: (m, _) => m.toFirestore(),
      )
      .get();
  return s.data();
});

// Directorio opt-in: usuarios descubribles con Strava conectado, menos yo y los
// que ya tengan relación activa.
final suggestionsProvider =
    FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final priv = ref.watch(socialPrivacyProvider).valueOrNull;
  if (uid == null || priv == null || !priv.discoverable) return const [];

  final conns = ref.watch(myConnectionsProvider).valueOrNull ?? const [];
  final excluded = {
    uid,
    for (final c in conns)
      if (c.status != ConnectionStatus.declined &&
          c.status != ConnectionStatus.removed)
        c.other(uid),
  };

  final snap = await FirebaseFirestore.instance
      .collection('users')
      .where('social.discoverable', isEqualTo: true)
      .limit(50)
      .get();

  final candidates = [
    for (final d in snap.docs)
      RunnerDirectoryEntry(
        uid: d.id,
        stravaAthleteId: d.data()['stravaId'] as String?,
        stravaConnected: d.data()['stravaConnected'] as bool? ?? false,
        discoverable: true,
      ),
  ];
  final matched = const StravaIdentityMatcher().suggestions(
    meUid: uid,
    meDiscoverable: true,
    candidates: candidates,
    excludedUids: excluded,
  );
  final byId = {for (final d in snap.docs) d.id: d};
  return [for (final m in matched) UserModel.fromFirestore(byId[m.uid]!)];
});

final connectionControllerProvider =
    Provider((ref) => ConnectionController(ref));

class ConnectionController {
  ConnectionController(this.ref);
  final Ref ref;

  Future<void> setDiscoverable(bool value) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'social': {'discoverable': value}
    }, SetOptions(merge: true));
  }

  Future<void> setPrivate(bool value) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'social': {'private': value}
    }, SetOptions(merge: true));
  }

  Future<void> request(String other, ConnectionSource source) => _apply(
      other,
      (cur, me) => _svc.request(
          current: cur, requester: me, recipient: other, source: source));

  Future<void> accept(String other) =>
      _apply(other, (cur, me) => _svc.accept(current: cur!, actor: me));

  Future<void> decline(String other) =>
      _apply(other, (cur, me) => _svc.decline(current: cur!, actor: me));

  Future<void> remove(String other) =>
      _apply(other, (cur, me) => _svc.remove(current: cur!, actor: me));

  Future<void> block(String other) =>
      _apply(other, (cur, me) => _svc.block(current: cur!, actor: me));

  Future<void> _apply(String other,
      ConnectionOutcome Function(RunnerConnection?, String me) op) async {
    final me = ref.read(authStateProvider).valueOrNull?.uid;
    if (me == null) return;
    final repo = ref.read(connectionRepositoryProvider);
    final cur = await repo.find(me, other);
    final out = op(cur, me);
    if (out.changed && out.connection != null) {
      await repo.save(out.connection!);
    }
  }
}
