import 'conquest_interaction.dart';
import 'conquest_post.dart';

class ConquestAuthor {
  const ConquestAuthor({
    required this.userId,
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
}

class ConquestFeedItem {
  const ConquestFeedItem({
    required this.post,
    required this.author,
    this.myReaction,
  });

  final ConquestPost post;
  final ConquestAuthor author;
  final ReactionType? myReaction;

  ConquestFeedItem copyWith({
    ConquestPost? post,
    ConquestAuthor? author,
    ReactionType? myReaction,
    bool clearReaction = false,
  }) =>
      ConquestFeedItem(
        post: post ?? this.post,
        author: author ?? this.author,
        myReaction: clearReaction ? null : myReaction ?? this.myReaction,
      );
}

class ConquestFeedCursor {
  const ConquestFeedCursor({
    required this.createdAtSeconds,
    required this.createdAtNanoseconds,
    required this.id,
  });

  /// Firestore ordena timestamps con precision de nanosegundos. Conservar las
  /// dos partes evita saltos o duplicados entre paginas con fechas cercanas.
  final int createdAtSeconds;
  final int createdAtNanoseconds;
  final String id;
}

class ConquestFeedPage {
  const ConquestFeedPage({
    required this.items,
    required this.hasMore,
    this.nextCursor,
  });

  final List<ConquestFeedItem> items;
  final ConquestFeedCursor? nextCursor;
  final bool hasMore;
}

/// Política pura compartida por paginación y pruebas de feed.
class ConquestFeedPolicy {
  const ConquestFeedPolicy();

  bool isEligiblePermanent(ConquestPost post) =>
      !post.isStory &&
      !post.isDeleted &&
      !post.isArchived &&
      post.moderationStatus == 'ok' &&
      (post.visibility == ConquestVisibility.public ||
          post.visibility == ConquestVisibility.connections);

  List<ConquestFeedItem> merge(
    Iterable<ConquestFeedItem> current,
    Iterable<ConquestFeedItem> incoming,
  ) {
    final byId = <String, ConquestFeedItem>{
      for (final item in current) item.post.id: item,
      for (final item in incoming) item.post.id: item,
    };
    final result = byId.values.toList(growable: false);
    result.sort((a, b) {
      final byDate = b.post.createdAt.compareTo(a.post.createdAt);
      return byDate != 0 ? byDate : b.post.id.compareTo(a.post.id);
    });
    return result;
  }
}
