import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_feed.dart';
import 'package:runrace/conquest/conquest_post.dart';

void main() {
  const policy = ConquestFeedPolicy();
  final now = DateTime.utc(2026, 7, 17, 12);

  ConquestFeedItem item(
    String id, {
    DateTime? createdAt,
    ConquestVisibility visibility = ConquestVisibility.public,
    DateTime? expiresAt,
    bool isArchived = false,
    bool isDeleted = false,
    String moderationStatus = 'ok',
  }) {
    final post = ConquestPost(
      id: id,
      userId: 'author-$id',
      type: ConquestType.photo,
      visibility: visibility,
      createdAt: createdAt ?? now,
      expiresAt: expiresAt,
      isArchived: isArchived,
      isDeleted: isDeleted,
      moderationStatus: moderationStatus,
    );
    return ConquestFeedItem(
      post: post,
      author: ConquestAuthor(
        userId: post.userId,
        displayName: 'Runner $id',
      ),
    );
  }

  test('solo admite publicaciones permanentes visibles y moderadas', () {
    expect(policy.isEligiblePermanent(item('public').post), isTrue);
    expect(
      policy.isEligiblePermanent(
        item('connection', visibility: ConquestVisibility.connections).post,
      ),
      isTrue,
    );
    expect(
      policy.isEligiblePermanent(
        item('private', visibility: ConquestVisibility.onlyMe).post,
      ),
      isFalse,
    );
    expect(
      policy.isEligiblePermanent(
        item('story', expiresAt: now.add(const Duration(hours: 1))).post,
      ),
      isFalse,
    );
    expect(
      policy.isEligiblePermanent(item('archived', isArchived: true).post),
      isFalse,
    );
    expect(
      policy.isEligiblePermanent(item('deleted', isDeleted: true).post),
      isFalse,
    );
    expect(
      policy.isEligiblePermanent(
        item('hidden', moderationStatus: 'hidden').post,
      ),
      isFalse,
    );
  });

  test('fusiona páginas sin duplicados y con orden estable', () {
    final newest = item('z', createdAt: now.add(const Duration(minutes: 2)));
    final sameTimeA = item('a', createdAt: now);
    final sameTimeB = item('b', createdAt: now);
    final updatedA = item('a', createdAt: now);

    final merged = policy.merge(
      [sameTimeA, sameTimeB],
      [newest, updatedA],
    );

    expect(merged.map((entry) => entry.post.id), ['z', 'b', 'a']);
    expect(merged, hasLength(3));
  });
}
