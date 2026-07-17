import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../providers/auth_provider.dart';
import '../social/runner_connection.dart';
import '../social/social_providers.dart';
import 'conquest_interaction.dart';
import 'conquest_interaction_repository.dart';

final conquestInteractionRepositoryProvider =
    Provider<ConquestInteractionRepository>(
  (_) => FirebaseConquestInteractionRepository(),
);

final myConquestReactionProvider =
    StreamProvider.autoDispose.family<ReactionType?, String>((ref, postId) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  if (uid == null) return Stream.value(null);
  return ref
      .watch(conquestInteractionRepositoryProvider)
      .watchMyReaction(postId: postId, userId: uid)
      .map((reaction) => reaction?.kind);
});

final conquestCommentsProvider = StreamProvider.autoDispose
    .family<List<ConquestComment>, String>((ref, postId) {
  return ref
      .watch(conquestInteractionRepositoryProvider)
      .watchVisibleComments(postId);
});

final blockedRunnerIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final uid = ref.watch(authStateProvider).valueOrNull?.uid;
  final connections = ref.watch(myConnectionsProvider).valueOrNull ?? const [];
  if (uid == null) return const {};
  return {
    for (final connection in connections)
      if (connection.status == ConnectionStatus.blocked) connection.other(uid),
  };
});

class ConquestInteractionController {
  ConquestInteractionController(this.ref);

  final Ref ref;
  static const _uuid = Uuid();

  ConquestInteractionRepository get _repository =>
      ref.read(conquestInteractionRepositoryProvider);

  Future<SetConquestReactionResult> setReaction(
    String postId,
    ReactionType? kind,
  ) =>
      _repository.setConquestReaction(postId: postId, kind: kind);

  Future<CreateConquestCommentResult> createComment(
    String postId,
    String text, {
    required String commentId,
  }) =>
      _repository.createConquestComment(
        postId: postId,
        commentId: commentId,
        text: text,
      );

  String newCommentId() => _uuid.v4();

  Future<void> deleteComment(String postId, String commentId) =>
      _repository.deleteConquestComment(
        postId: postId,
        commentId: commentId,
      );

  Future<ReportConquestPostResult> report(
    String postId,
    ReportReason reason, {
    String? details,
  }) =>
      _repository.reportConquestPost(
        postId: postId,
        reason: reason,
        details: details,
      );

  Future<void> blockRunner(String userId) => _repository.blockRunner(userId);

  Future<void> unblockRunner(String userId) =>
      _repository.unblockRunner(userId);
}

final conquestInteractionControllerProvider =
    Provider<ConquestInteractionController>(ConquestInteractionController.new);
