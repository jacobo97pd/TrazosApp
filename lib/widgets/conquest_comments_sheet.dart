import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../conquest/conquest_interaction.dart';
import '../conquest/conquest_interaction_providers.dart';
import '../core/theme.dart';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

Future<void> showConquestCommentsSheet(
  BuildContext context, {
  required String postId,
  required String postOwnerId,
  VoidCallback? onChanged,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.82,
        child: _ConquestCommentsSheet(
          postId: postId,
          postOwnerId: postOwnerId,
          onChanged: onChanged,
        ),
      ),
    );

class _ConquestCommentsSheet extends ConsumerStatefulWidget {
  const _ConquestCommentsSheet({
    required this.postId,
    required this.postOwnerId,
    this.onChanged,
  });

  final String postId;
  final String postOwnerId;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_ConquestCommentsSheet> createState() =>
      _ConquestCommentsSheetState();
}

class _ConquestCommentsSheetState
    extends ConsumerState<_ConquestCommentsSheet> {
  final _controller = TextEditingController();
  bool _sending = false;
  String? _pendingCommentId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final interaction = ref.read(conquestInteractionControllerProvider);
      final commentId = _pendingCommentId ??= interaction.newCommentId();
      await interaction.createComment(
        widget.postId,
        _controller.text,
        commentId: commentId,
      );
      logAnalyticsBestEffort(
        () => ref.read(analyticsServiceProvider).logCommentCreated(),
      );
      _controller.clear();
      _pendingCommentId = null;
      widget.onChanged?.call();
    } on ArgumentError catch (error) {
      _show(error.message?.toString() ?? 'Comentario no válido.');
    } catch (_) {
      _show('No se pudo publicar el comentario.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ConquestComment comment) async {
    try {
      await ref
          .read(conquestInteractionControllerProvider)
          .deleteComment(widget.postId, comment.id);
      widget.onChanged?.call();
    } catch (_) {
      _show('No se pudo eliminar el comentario.');
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final comments = ref.watch(conquestCommentsProvider(widget.postId));
    final currentUid = ref.watch(authStateProvider).valueOrNull?.uid;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Comentarios',
                    style: AppTextStyles.headlineMedium,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: comments.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
              error: (_, __) => Center(
                child: Text(
                  'No se pudieron cargar los comentarios.',
                  style: AppTextStyles.caption,
                ),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text(
                        'Sé el primero en comentar.',
                        style: AppTextStyles.caption,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final comment = items[index];
                        final canDelete = currentUid == comment.authorId ||
                            currentUid == widget.postOwnerId;
                        return _CommentTile(
                          comment: comment,
                          onDelete: canDelete ? () => _delete(comment) : null,
                        );
                      },
                    ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ConquestInteractionValidation.maxCommentLength,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      hintText: 'Escribe un comentario',
                      counterText: '',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  tooltip: 'Publicar comentario',
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment, this.onDelete});

  final ConquestComment comment;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final initial = comment.authorName.trim().isEmpty
        ? 'T'
        : comment.authorName.trim()[0].toUpperCase();
    return ListTile(
      leading: CircleAvatar(
        foregroundImage:
            comment.authorPhotoUrl == null || comment.authorPhotoUrl!.isEmpty
                ? null
                : NetworkImage(comment.authorPhotoUrl!),
        child: Text(initial),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(comment.authorName, style: AppTextStyles.labelLarge),
          ),
          Text(
            DateFormat('dd MMM · HH:mm').format(comment.createdAt),
            style: AppTextStyles.caption,
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(comment.text, style: AppTextStyles.bodyMedium),
      ),
      trailing: onDelete == null
          ? null
          : IconButton(
              onPressed: onDelete,
              tooltip: 'Eliminar comentario',
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
    );
  }
}
