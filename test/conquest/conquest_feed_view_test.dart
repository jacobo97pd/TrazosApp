import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_feed.dart';
import 'package:runrace/conquest/conquest_feed_providers.dart';
import 'package:runrace/conquest/conquest_feed_repository.dart';
import 'package:runrace/conquest/conquest_post.dart';
import 'package:runrace/providers/auth_provider.dart';
import 'package:runrace/screens/conquest_feed_view.dart';
import 'package:runrace/services/analytics_service.dart';

void main() {
  testWidgets('muestra las historias activas aunque el feed este vacio',
      (tester) async {
    final repository = _StoriesFeedRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          conquestFeedRepositoryProvider.overrideWithValue(repository),
          analyticsServiceProvider.overrideWithValue(
            const NoopAnalyticsService(),
          ),
          authStateProvider.overrideWith((_) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ConquestFeedView()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Historias'), findsOneWidget);
    expect(find.bySemanticsLabel('Abrir historia de Ana'), findsOneWidget);
    expect(repository.storyRequests, 1);
  });
}

class _StoriesFeedRepository implements ConquestFeedRepository {
  int storyRequests = 0;

  @override
  Future<ConquestFeedPage> fetchPage({
    ConquestFeedCursor? cursor,
    int limit = 20,
  }) async =>
      const ConquestFeedPage(items: [], hasMore: false);

  @override
  Future<List<ConquestFeedItem>> fetchStories({int limit = 20}) async {
    storyRequests += 1;
    final post = ConquestPost(
      id: 'story-1',
      userId: 'runner-1',
      type: ConquestType.story,
      visibility: ConquestVisibility.public,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
    return [
      ConquestFeedItem(
        post: post,
        author: const ConquestAuthor(
          userId: 'runner-1',
          displayName: 'Ana',
        ),
      ),
    ];
  }

  @override
  Future<ConquestFeedItem> fetchDetail(String postId) =>
      throw UnimplementedError();
}
