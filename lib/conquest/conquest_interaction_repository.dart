import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'conquest_interaction.dart';

abstract interface class ConquestInteractionRepository {
  /// Establece el estado final de la reaccion. `null` significa sin reaccion.
  Future<SetConquestReactionResult> setConquestReaction({
    required String postId,
    required ReactionType? kind,
  });

  /// Observa unicamente la reaccion del usuario autenticado indicado.
  Stream<ConquestReaction?> watchMyReaction({
    required String postId,
    required String userId,
  });

  Future<CreateConquestCommentResult> createConquestComment({
    required String postId,
    required String commentId,
    required String text,
  });

  Future<void> deleteConquestComment({
    required String postId,
    required String commentId,
  });

  /// Solo emite comentarios no borrados y aprobados, del mas antiguo al nuevo.
  Stream<List<ConquestComment>> watchVisibleComments(String postId);

  Future<ReportConquestPostResult> reportConquestPost({
    required String postId,
    required ReportReason reason,
    String? details,
  });

  Future<void> blockRunner(String otherUserId);

  Future<void> unblockRunner(String otherUserId);
}

/// Escrituras sociales mediante callables confiables y lecturas en tiempo real
/// directamente desde Firestore. Las instancias son inyectables para tests y
/// emuladores; produccion usa siempre la region europea del proyecto.
class FirebaseConquestInteractionRepository
    implements ConquestInteractionRepository {
  FirebaseConquestInteractionRepository({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: functionsRegion),
        _firestore = firestore ?? FirebaseFirestore.instance;

  static const String functionsRegion = 'europe-west1';

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _reactionReference(
    String postId,
    String userId,
  ) =>
      _firestore
          .collection('conquest_posts')
          .doc(ConquestInteractionValidation.documentId(postId))
          .collection('reactions')
          .doc(ConquestInteractionValidation.documentId(userId));

  CollectionReference<Map<String, dynamic>> _commentsReference(
    String postId,
  ) =>
      _firestore
          .collection('conquest_posts')
          .doc(ConquestInteractionValidation.documentId(postId))
          .collection('comments');

  @override
  Future<SetConquestReactionResult> setConquestReaction({
    required String postId,
    required ReactionType? kind,
  }) async {
    final result = await _functions
        .httpsCallable('setConquestReaction')
        .call(<String, dynamic>{
      'postId': ConquestInteractionValidation.documentId(postId),
      'kind': kind?.wireValue,
    });
    final data = _responseMap(result.data, 'setConquestReaction');
    final reactionValue = data['reaction'];
    final reaction = reactionValue == null
        ? null
        : ReactionTypeWire.tryParse(reactionValue as String?);
    if (reactionValue != null && reaction == null) {
      throw StateError('setConquestReaction devolvio una reaccion no valida.');
    }

    return SetConquestReactionResult(
      changed: _bool(data, 'changed'),
      reaction: reaction,
      likesCount: _nonNegativeInt(data, 'likesCount'),
      applauseCount: _nonNegativeInt(data, 'applauseCount'),
    );
  }

  @override
  Stream<ConquestReaction?> watchMyReaction({
    required String postId,
    required String userId,
  }) =>
      _reactionReference(postId, userId).snapshots().map((snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;

        final kind = ReactionTypeWire.tryParse(data['kind'] as String?);
        if (kind == null) return null;
        return ConquestReaction(
          postId: postId,
          userId: data['userId'] as String? ?? snapshot.id,
          kind: kind,
          createdAt: _dateTime(data['createdAt']),
          updatedAt: _nullableDateTime(data['updatedAt']),
        );
      });

  @override
  Future<CreateConquestCommentResult> createConquestComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    final normalizedPostId = ConquestInteractionValidation.documentId(postId);
    final normalizedCommentId =
        ConquestInteractionValidation.documentId(commentId);
    final normalizedText = ConquestInteractionValidation.commentText(text);
    final result = await _functions
        .httpsCallable('createConquestComment')
        .call(<String, dynamic>{
      'postId': normalizedPostId,
      'commentId': normalizedCommentId,
      'text': normalizedText,
    });
    final data = _responseMap(result.data, 'createConquestComment');
    return CreateConquestCommentResult(
      commentId: data['commentId'] as String? ?? normalizedCommentId,
      created: _bool(data, 'created'),
    );
  }

  @override
  Future<void> deleteConquestComment({
    required String postId,
    required String commentId,
  }) async {
    await _functions
        .httpsCallable('deleteConquestComment')
        .call(<String, dynamic>{
      'postId': ConquestInteractionValidation.documentId(postId),
      'commentId': ConquestInteractionValidation.documentId(commentId),
    });
  }

  @override
  Stream<List<ConquestComment>> watchVisibleComments(String postId) {
    final normalizedPostId = ConquestInteractionValidation.documentId(postId);
    return _commentsReference(normalizedPostId)
        .where('isDeleted', isEqualTo: false)
        .where(
          'moderationStatus',
          isEqualTo: ConquestModerationStatus.ok.wireValue,
        )
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((document) => _commentFromDocument(
                  normalizedPostId,
                  document,
                ))
            .toList(growable: false));
  }

  @override
  Future<ReportConquestPostResult> reportConquestPost({
    required String postId,
    required ReportReason reason,
    String? details,
  }) async {
    final result = await _functions
        .httpsCallable('reportConquestPost')
        .call(<String, dynamic>{
      'postId': ConquestInteractionValidation.documentId(postId),
      'reason': reason.wireValue,
      'details': ConquestInteractionValidation.reportDetails(details),
    });
    final data = _responseMap(result.data, 'reportConquestPost');
    final moderationStatus = ConquestModerationStatusWire.tryParse(
      data['moderationStatus'] as String?,
    );
    if (moderationStatus == null) {
      throw StateError('reportConquestPost devolvio un estado no valido.');
    }
    return ReportConquestPostResult(
      created: _bool(data, 'created'),
      reportCount: _nonNegativeInt(data, 'reportCount'),
      moderationStatus: moderationStatus,
    );
  }

  @override
  Future<void> blockRunner(String otherUserId) => _runnerMutation(
        'blockRunner',
        otherUserId,
      );

  @override
  Future<void> unblockRunner(String otherUserId) => _runnerMutation(
        'unblockRunner',
        otherUserId,
      );

  Future<void> _runnerMutation(String callable, String otherUserId) async {
    await _functions.httpsCallable(callable).call(<String, dynamic>{
      'otherUserId': ConquestInteractionValidation.documentId(otherUserId),
    });
  }

  static ConquestComment _commentFromDocument(
    String postId,
    QueryDocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();
    final moderationStatus = ConquestModerationStatusWire.tryParse(
          data['moderationStatus'] as String?,
        ) ??
        ConquestModerationStatus.underReview;
    return ConquestComment(
      id: document.id,
      postId: postId,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      authorPhotoUrl: data['authorPhotoUrl'] as String?,
      text: data['text'] as String? ?? '',
      createdAt: _dateTime(data['createdAt']),
      updatedAt: _nullableDateTime(data['updatedAt']),
      deletedAt: _nullableDateTime(data['deletedAt']),
      isDeleted: data['isDeleted'] as bool? ?? false,
      moderationStatus: moderationStatus,
    );
  }

  static Map<String, dynamic> _responseMap(Object? value, String callable) {
    if (value is! Map) {
      throw StateError('$callable devolvio una respuesta no valida.');
    }
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  static bool _bool(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is bool) return value;
    throw StateError('El campo $key no es booleano.');
  }

  static int _nonNegativeInt(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is num && value >= 0) return value.toInt();
    throw StateError('El campo $key no es un entero no negativo.');
  }

  static DateTime _dateTime(Object? value) =>
      _nullableDateTime(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _nullableDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
    }
    return null;
  }
}
