import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_interaction.dart';

void main() {
  group('wire values', () {
    test('reaction types are closed and round-trip', () {
      expect(ReactionType.like.wireValue, 'like');
      expect(ReactionType.applause.wireValue, 'applause');
      expect(ReactionTypeWire.tryParse('like'), ReactionType.like);
      expect(ReactionTypeWire.tryParse('applause'), ReactionType.applause);
      expect(ReactionTypeWire.tryParse('heart'), isNull);
      expect(ReactionTypeWire.tryParse(null), isNull);
    });

    test('report reasons use the backend contract', () {
      expect(ReportReason.hateSpeech.wireValue, 'hate_speech');
      expect(ReportReason.sexualContent.wireValue, 'sexual_content');
      expect(
        ReportReason.dangerousActivity.wireValue,
        'dangerous_activity',
      );
      for (final reason in ReportReason.values) {
        expect(
          ReportReasonWire.tryParse(reason.wireValue),
          reason,
        );
      }
      expect(ReportReasonWire.tryParse('custom_reason'), isNull);
    });

    test('moderation states use snake case where needed', () {
      expect(
        ConquestModerationStatus.underReview.wireValue,
        'under_review',
      );
      for (final status in ConquestModerationStatus.values) {
        expect(
          ConquestModerationStatusWire.tryParse(status.wireValue),
          status,
        );
      }
    });
  });

  group('deterministic paths', () {
    test('one reaction and report per post and user', () {
      expect(
        ConquestReaction.documentPath('post-1', 'user-1'),
        'conquest_posts/post-1/reactions/user-1',
      );
      expect(
        ConquestReport.documentPath('post-1', 'user-1'),
        'conquest_posts/post-1/reports/user-1',
      );
      expect(
        ConquestReaction.documentPath('post-1', 'user-1'),
        ConquestReaction.documentPath('post-1', 'user-1'),
      );
      expect(
        ConquestReaction.documentPath('post-1', 'user-1'),
        isNot(ConquestReaction.documentPath('post-1', 'user-2')),
      );
    });

    test('comment path preserves the client id across retries', () {
      expect(
        ConquestComment.documentPath('post-1', 'request-123'),
        'conquest_posts/post-1/comments/request-123',
      );
      expect(
        ConquestComment.documentPath('post-1', 'request-123'),
        ConquestComment.documentPath('post-1', 'request-123'),
      );
    });

    test('rejects invalid Firestore path segments', () {
      expect(
        () => ConquestReaction.documentPath('', 'user-1'),
        throwsArgumentError,
      );
      expect(
        () => ConquestComment.documentPath('post/1', 'comment-1'),
        throwsArgumentError,
      );
    });
  });

  group('comment validation', () {
    test('normalizes whitespace before sending', () {
      expect(
        ConquestInteractionValidation.commentText('  Gran conquista! \n'),
        'Gran conquista!',
      );
    });

    test('accepts boundaries from 1 to 500 characters', () {
      final max = List.filled(500, 'a').join();
      expect(ConquestInteractionValidation.commentText(' x '), 'x');
      expect(ConquestInteractionValidation.commentText(max), max);
    });

    test('rejects blank and longer than 500 characters', () {
      final tooLong = List.filled(501, 'a').join();
      expect(
        () => ConquestInteractionValidation.commentText('  \n '),
        throwsArgumentError,
      );
      expect(
        () => ConquestInteractionValidation.commentText(tooLong),
        throwsArgumentError,
      );
    });
  });

  group('report details', () {
    test('normalizes optional details', () {
      expect(ConquestInteractionValidation.reportDetails(null), isNull);
      expect(ConquestInteractionValidation.reportDetails('   '), isNull);
      expect(
        ConquestInteractionValidation.reportDetails('  contexto  '),
        'contexto',
      );
    });

    test('rejects details longer than 500 characters', () {
      expect(
        () => ConquestInteractionValidation.reportDetails(
          List.filled(501, 'a').join(),
        ),
        throwsArgumentError,
      );
    });
  });

  test('soft-deleted or moderated comments are not visible', () {
    final createdAt = DateTime.utc(2026, 7, 17);
    ConquestComment comment({
      bool deleted = false,
      ConquestModerationStatus status = ConquestModerationStatus.ok,
    }) =>
        ConquestComment(
          id: 'comment-1',
          postId: 'post-1',
          authorId: 'user-1',
          authorName: 'Runner',
          text: 'Buen trabajo',
          createdAt: createdAt,
          isDeleted: deleted,
          moderationStatus: status,
        );

    expect(comment().isVisible, isTrue);
    expect(comment(deleted: true).isVisible, isFalse);
    expect(
      comment(status: ConquestModerationStatus.underReview).isVisible,
      isFalse,
    );
    expect(
      comment(status: ConquestModerationStatus.hidden).isVisible,
      isFalse,
    );
  });
}
