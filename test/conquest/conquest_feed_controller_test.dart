import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_feed.dart';
import 'package:runrace/conquest/conquest_feed_providers.dart';
import 'package:runrace/conquest/conquest_feed_repository.dart';
import 'package:runrace/conquest/conquest_post.dart';

void main() {
  test('refresh discards an older loadMore completion', () async {
    final repository = _ControlledFeedRepository();
    final container = ProviderContainer(
      overrides: [
        conquestFeedRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      conquestFeedProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await _nextEventLoop();
    expect(repository.requests, hasLength(1));
    repository.requests[0].complete(
      _page('initial', hasMore: true, cursorId: 'initial-cursor'),
    );
    await container.read(conquestFeedProvider.future);

    final controller = container.read(conquestFeedProvider.notifier);
    final loadMore = controller.loadMore();
    await _nextEventLoop();
    expect(repository.requests, hasLength(2));

    final refresh = controller.refresh();
    await _nextEventLoop();
    expect(repository.requests, hasLength(3));
    repository.requests[2].complete(_page('fresh'));
    await refresh;

    repository.requests[1].complete(_page('stale-page'));
    await loadMore;

    final state = container.read(conquestFeedProvider).requireValue;
    expect(state.items.map((item) => item.post.id), ['fresh']);
    expect(state.isLoadingMore, isFalse);
  });
}

Future<void> _nextEventLoop() => Future<void>.delayed(Duration.zero);

ConquestFeedPage _page(
  String id, {
  bool hasMore = false,
  String? cursorId,
}) {
  final post = ConquestPost(
    id: id,
    userId: 'author-$id',
    type: ConquestType.text,
    visibility: ConquestVisibility.public,
    createdAt: DateTime.utc(2026, 7, 17),
  );
  return ConquestFeedPage(
    items: [
      ConquestFeedItem(
        post: post,
        author: ConquestAuthor(
          userId: post.userId,
          displayName: 'Runner $id',
        ),
      ),
    ],
    hasMore: hasMore,
    nextCursor: cursorId == null
        ? null
        : ConquestFeedCursor(
            createdAtSeconds: 1784246400,
            createdAtNanoseconds: 123456789,
            id: cursorId,
          ),
  );
}

class _ControlledFeedRepository implements ConquestFeedRepository {
  final List<Completer<ConquestFeedPage>> requests = [];

  @override
  Future<ConquestFeedPage> fetchPage({
    ConquestFeedCursor? cursor,
    int limit = 20,
  }) {
    final request = Completer<ConquestFeedPage>();
    requests.add(request);
    return request.future;
  }

  @override
  Future<ConquestFeedItem> fetchDetail(String postId) =>
      throw UnimplementedError();

  @override
  Future<List<ConquestFeedItem>> fetchStories({int limit = 20}) =>
      throw UnimplementedError();
}
