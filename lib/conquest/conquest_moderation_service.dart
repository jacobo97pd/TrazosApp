import 'conquest_interaction.dart';

/// Politica pura de moderacion automatica por reportes unicos.
class ConquestModerationService {
  const ConquestModerationService({
    this.underReviewThreshold = 3,
    this.hiddenThreshold = 5,
  })  : assert(underReviewThreshold > 0),
        assert(hiddenThreshold > underReviewThreshold);

  final int underReviewThreshold;
  final int hiddenThreshold;

  /// Estado que corresponde exactamente al numero de reportes unicos.
  ConquestModerationStatus statusForReportCount(int reportCount) {
    if (reportCount < 0) {
      throw ArgumentError.value(
        reportCount,
        'reportCount',
        'El numero de reportes no puede ser negativo.',
      );
    }
    if (reportCount >= hiddenThreshold) {
      return ConquestModerationStatus.hidden;
    }
    if (reportCount >= underReviewThreshold) {
      return ConquestModerationStatus.underReview;
    }
    return ConquestModerationStatus.ok;
  }

  /// Aplica los umbrales sin rebajar estados mas restrictivos. `removed` es
  /// siempre terminal y solo puede decidirlo una persona moderadora.
  ConquestModerationStatus nextStatus({
    required ConquestModerationStatus current,
    required int reportCount,
  }) {
    if (current == ConquestModerationStatus.removed) return current;
    final candidate = statusForReportCount(reportCount);
    return _severity(candidate) > _severity(current) ? candidate : current;
  }

  static int _severity(ConquestModerationStatus status) => switch (status) {
        ConquestModerationStatus.ok => 0,
        ConquestModerationStatus.underReview => 1,
        ConquestModerationStatus.hidden => 2,
        ConquestModerationStatus.removed => 3,
      };
}
