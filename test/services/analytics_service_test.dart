import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/services/analytics_service.dart';

void main() {
  test('best effort absorbs synchronous analytics errors', () {
    expect(
      () => logAnalyticsBestEffort(
        () => throw StateError('analytics unavailable'),
      ),
      returnsNormally,
    );
  });

  test('best effort absorbs asynchronous analytics errors', () async {
    final uncaught = <Object>[];
    await runZonedGuarded(
      () async {
        logAnalyticsBestEffort(
          () => Future<void>.error(StateError('analytics unavailable')),
        );
        await Future<void>.delayed(Duration.zero);
      },
      (error, _) => uncaught.add(error),
    );

    expect(uncaught, isEmpty);
  });
}
