import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Primera visualizacion de una historia por un usuario.
class StoryView {
  const StoryView({
    required this.storyId,
    required this.viewerId,
    required this.viewedAt,
  });

  final String storyId;
  final String viewerId;
  final DateTime viewedAt;

  /// Cada usuario ocupa un unico documento dentro de la historia.
  static String documentPath(String storyId, String viewerId) =>
      'conquest_posts/$storyId/story_views/$viewerId';
}

abstract interface class StoryViewRepository {
  /// Registra la primera vista. Devuelve `false` si ya estaba registrada.
  Future<bool> recordView({
    required String storyId,
    required String viewerId,
  });

  Future<bool> hasViewed({
    required String storyId,
    required String viewerId,
  });

  /// Solo el propietario de la historia puede enumerar sus vistas.
  Stream<List<StoryView>> watchForStory(String storyId);
}

/// Implementacion pequena para probar el contrato sin depender de Firebase.
class InMemoryStoryViewRepository implements StoryViewRepository {
  InMemoryStoryViewRepository({DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, StoryView> _views = {};
  final StreamController<String> _changes = StreamController.broadcast();

  @override
  Future<bool> recordView({
    required String storyId,
    required String viewerId,
  }) async {
    final path = StoryView.documentPath(storyId, viewerId);
    if (_views.containsKey(path)) return false;

    _views[path] = StoryView(
      storyId: storyId,
      viewerId: viewerId,
      viewedAt: _clock(),
    );
    _changes.add(storyId);
    return true;
  }

  @override
  Future<bool> hasViewed({
    required String storyId,
    required String viewerId,
  }) async =>
      _views.containsKey(StoryView.documentPath(storyId, viewerId));

  @override
  Stream<List<StoryView>> watchForStory(String storyId) async* {
    yield _snapshot(storyId);
    yield* _changes.stream
        .where((changedStoryId) => changedStoryId == storyId)
        .map((_) => _snapshot(storyId));
  }

  List<StoryView> _snapshot(String storyId) {
    final result = _views.values
        .where((view) => view.storyId == storyId)
        .toList(growable: false);
    result.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return result;
  }

  Future<void> dispose() => _changes.close();
}

class FirestoreStoryViewRepository implements StoryViewRepository {
  FirestoreStoryViewRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _viewsFor(String storyId) =>
      _firestore
          .collection('conquest_posts')
          .doc(storyId)
          .collection('story_views');

  @override
  Future<bool> recordView({
    required String storyId,
    required String viewerId,
  }) {
    final viewRef = _viewsFor(storyId).doc(viewerId);
    return _firestore.runTransaction<bool>((transaction) async {
      final existing = await transaction.get(viewRef);
      if (existing.exists) return false;

      transaction.set(viewRef, {
        'storyId': storyId,
        'viewerId': viewerId,
        'viewedAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  @override
  Future<bool> hasViewed({
    required String storyId,
    required String viewerId,
  }) async =>
      (await _viewsFor(storyId).doc(viewerId).get()).exists;

  @override
  Stream<List<StoryView>> watchForStory(String storyId) => _viewsFor(storyId)
      .orderBy('viewedAt', descending: true)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => _fromDocument(storyId, doc))
          .toList(growable: false));

  static StoryView _fromDocument(
    String storyId,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    return StoryView(
      storyId: storyId,
      viewerId: data['viewerId'] as String? ?? document.id,
      viewedAt: (data['viewedAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }
}
