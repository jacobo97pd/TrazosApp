import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/story_view_repository.dart';

void main() {
  test('documentPath identifica una vista por historia y usuario', () {
    expect(
      StoryView.documentPath('story-1', 'viewer-1'),
      'conquest_posts/story-1/story_views/viewer-1',
    );
    expect(
      StoryView.documentPath('story-1', 'viewer-1'),
      StoryView.documentPath('story-1', 'viewer-1'),
    );
    expect(
      StoryView.documentPath('story-1', 'viewer-1'),
      isNot(StoryView.documentPath('story-1', 'viewer-2')),
    );
    expect(
      StoryView.documentPath('story-1', 'viewer-1'),
      isNot(StoryView.documentPath('story-2', 'viewer-1')),
    );
  });

  test('recordView es idempotente y conserva la primera fecha', () async {
    final firstViewedAt = DateTime.utc(2026, 1, 1, 10);
    var clock = firstViewedAt;
    final repository = InMemoryStoryViewRepository(clock: () => clock);
    addTearDown(repository.dispose);

    expect(
      await repository.hasViewed(
        storyId: 'story-1',
        viewerId: 'viewer-1',
      ),
      isFalse,
    );
    expect(
      await repository.recordView(
        storyId: 'story-1',
        viewerId: 'viewer-1',
      ),
      isTrue,
    );
    expect(
      await repository.hasViewed(
        storyId: 'story-1',
        viewerId: 'viewer-1',
      ),
      isTrue,
    );

    clock = DateTime.utc(2026, 1, 1, 12);
    expect(
      await repository.recordView(
        storyId: 'story-1',
        viewerId: 'viewer-1',
      ),
      isFalse,
    );

    final views = await repository.watchForStory('story-1').first;
    expect(views, hasLength(1));
    expect(views.single.storyId, 'story-1');
    expect(views.single.viewerId, 'viewer-1');
    expect(views.single.viewedAt, firstViewedAt);
  });

  test('acepta distintos usuarios y aisla las vistas por historia', () async {
    var clock = DateTime.utc(2026, 1, 1, 10);
    final repository = InMemoryStoryViewRepository(clock: () => clock);
    addTearDown(repository.dispose);

    await repository.recordView(
      storyId: 'story-1',
      viewerId: 'viewer-1',
    );
    clock = DateTime.utc(2026, 1, 1, 11);
    await repository.recordView(
      storyId: 'story-2',
      viewerId: 'viewer-1',
    );
    clock = DateTime.utc(2026, 1, 1, 12);
    await repository.recordView(
      storyId: 'story-1',
      viewerId: 'viewer-2',
    );

    final storyOneViews = await repository.watchForStory('story-1').first;
    final storyTwoViews = await repository.watchForStory('story-2').first;

    expect(
      storyOneViews.map((view) => view.viewerId),
      ['viewer-2', 'viewer-1'],
    );
    expect(storyTwoViews, hasLength(1));
    expect(storyTwoViews.single.viewerId, 'viewer-1');
    expect(storyTwoViews.single.storyId, 'story-2');
  });
}
