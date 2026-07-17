import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_interaction.dart';
import 'package:runrace/conquest/conquest_moderation_service.dart';

void main() {
  group('ConquestModerationService', () {
    const service = ConquestModerationService();

    test('keeps zero to two reports visible', () {
      for (var count = 0; count < 3; count++) {
        expect(
          service.statusForReportCount(count),
          ConquestModerationStatus.ok,
        );
      }
    });

    test('moves three and four reports under review', () {
      expect(
        service.statusForReportCount(3),
        ConquestModerationStatus.underReview,
      );
      expect(
        service.statusForReportCount(4),
        ConquestModerationStatus.underReview,
      );
    });

    test('hides at five reports and above', () {
      expect(
        service.statusForReportCount(5),
        ConquestModerationStatus.hidden,
      );
      expect(
        service.statusForReportCount(500),
        ConquestModerationStatus.hidden,
      );
    });

    test('rejects a negative report count', () {
      expect(() => service.statusForReportCount(-1), throwsArgumentError);
    });

    test('never downgrades a more restrictive status', () {
      expect(
        service.nextStatus(
          current: ConquestModerationStatus.hidden,
          reportCount: 1,
        ),
        ConquestModerationStatus.hidden,
      );
      expect(
        service.nextStatus(
          current: ConquestModerationStatus.removed,
          reportCount: 500,
        ),
        ConquestModerationStatus.removed,
      );
    });

    test('supports stricter configurable thresholds', () {
      const strict = ConquestModerationService(
        underReviewThreshold: 1,
        hiddenThreshold: 2,
      );
      expect(
        strict.statusForReportCount(1),
        ConquestModerationStatus.underReview,
      );
      expect(
        strict.statusForReportCount(2),
        ConquestModerationStatus.hidden,
      );
    });
  });
}
