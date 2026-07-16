import 'package:cloud_firestore/cloud_firestore.dart';

import 'runner_connection.dart';

/// Persistencia de conexiones. Documento único por par (id determinista).
abstract interface class RunnerConnectionRepository {
  Future<RunnerConnection?> find(String a, String b);
  Future<void> save(RunnerConnection connection);
  Stream<List<RunnerConnection>> watchForUser(String uid);
}

class InMemoryRunnerConnectionRepository implements RunnerConnectionRepository {
  final Map<String, RunnerConnection> _store = {};

  @override
  Future<RunnerConnection?> find(String a, String b) async =>
      _store[RunnerConnection.idFor(a, b)];

  @override
  Future<void> save(RunnerConnection c) async => _store[c.id] = c;

  @override
  Stream<List<RunnerConnection>> watchForUser(String uid) => Stream.value(
        _store.values.where((c) => c.involves(uid)).toList(),
      );
}

class FirestoreRunnerConnectionRepository
    implements RunnerConnectionRepository {
  final _col = FirebaseFirestore.instance.collection('connections');

  @override
  Future<RunnerConnection?> find(String a, String b) async {
    final snap = await _col.doc(RunnerConnection.idFor(a, b)).get();
    return snap.exists ? _fromDoc(snap) : null;
  }

  @override
  Future<void> save(RunnerConnection c) =>
      _col.doc(c.id).set(_toMap(c), SetOptions(merge: true));

  @override
  Stream<List<RunnerConnection>> watchForUser(String uid) => _col
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(_fromDoc).toList());

  static Map<String, dynamic> _toMap(RunnerConnection c) => {
        'requesterUserId': c.requesterUserId,
        'recipientUserId': c.recipientUserId,
        'participants': c.participants,
        'status': c.status.name,
        'source': c.source.name,
        'createdAt': Timestamp.fromDate(c.createdAt),
        'updatedAt': Timestamp.fromDate(c.updatedAt),
        'acceptedAt':
            c.acceptedAt == null ? null : Timestamp.fromDate(c.acceptedAt!),
        'blockedAt':
            c.blockedAt == null ? null : Timestamp.fromDate(c.blockedAt!),
        'blockedBy': c.blockedBy,
      };

  static RunnerConnection _fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    T? en<T>(List<T> values, String? name) {
      for (final v in values) {
        if ((v as Enum).name == name) return v;
      }
      return null;
    }

    return RunnerConnection(
      id: d.id,
      requesterUserId: m['requesterUserId'] as String,
      recipientUserId: m['recipientUserId'] as String,
      status: en(ConnectionStatus.values, m['status'] as String?) ??
          ConnectionStatus.pending,
      source: en(ConnectionSource.values, m['source'] as String?) ??
          ConnectionSource.username,
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
      acceptedAt: (m['acceptedAt'] as Timestamp?)?.toDate(),
      blockedAt: (m['blockedAt'] as Timestamp?)?.toDate(),
      blockedBy: m['blockedBy'] as String?,
    );
  }
}
