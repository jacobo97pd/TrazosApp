import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_interaction.dart';
import 'package:runrace/conquest/conquest_interaction_providers.dart';
import 'package:runrace/conquest/conquest_interaction_repository.dart';
import 'package:runrace/providers/auth_provider.dart';
import 'package:runrace/services/analytics_service.dart';
import 'package:runrace/widgets/conquest_comments_sheet.dart';

void main() {
  testWidgets('retry reuses commentId after a lost response', (tester) async {
    final repository = _RetryCommentRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conquestInteractionRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(
            const NoopAnalyticsService(),
          ),
          authStateProvider.overrideWith(
            (_) => Stream<User?>.value(null),
          ),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => showConquestCommentsSheet(
                  context,
                  postId: 'post-1',
                  postOwnerId: 'owner-1',
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Escribe un comentario'),
      'Gran conquista',
    );

    await tester.tap(find.byTooltip('Publicar comentario'));
    await tester.pumpAndSettle();
    expect(repository.commentIds, hasLength(1));

    await tester.tap(find.byTooltip('Publicar comentario'));
    await tester.pumpAndSettle();

    expect(repository.commentIds, hasLength(2));
    expect(repository.commentIds[1], repository.commentIds[0]);
  });
}

class _RetryCommentRepository extends Fake
    implements ConquestInteractionRepository {
  final List<String> commentIds = [];

  @override
  Stream<List<ConquestComment>> watchVisibleComments(String postId) =>
      Stream.value(const []);

  @override
  Future<CreateConquestCommentResult> createConquestComment({
    required String postId,
    required String commentId,
    required String text,
  }) async {
    commentIds.add(commentId);
    if (commentIds.length == 1) {
      throw StateError('response lost');
    }
    return CreateConquestCommentResult(commentId: commentId, created: false);
  }
}
