import 'conquest_post.dart';

/// Duración configurable de las historias (por defecto 24 h).
class StoryConfig {
  const StoryConfig({this.duration = const Duration(hours: 24)});
  final Duration duration;
}

/// Calcula la caducidad de una historia. Puro.
class StoryService {
  const StoryService({this.config = const StoryConfig()});
  final StoryConfig config;

  DateTime expiresAtFrom(DateTime now, {Duration? duration}) =>
      now.add(duration ?? config.duration);
}

/// Decide si una historia sigue activa y cuánto le queda. Puro y testeable.
class StoryExpirationService {
  const StoryExpirationService();

  bool isActive(ConquestPost p, DateTime now) =>
      p.isStory && !p.isDeleted && !p.isArchived && p.expiresAt!.isAfter(now);

  /// Tiempo restante (>= 0). Duration.zero si ya expiró.
  Duration timeRemaining(ConquestPost p, DateTime now) {
    if (!p.isStory) return Duration.zero;
    final d = p.expiresAt!.difference(now);
    return d.isNegative ? Duration.zero : d;
  }

  List<ConquestPost> activeOnly(Iterable<ConquestPost> posts, DateTime now) => [
        for (final p in posts)
          if (isActive(p, now)) p
      ];
}
