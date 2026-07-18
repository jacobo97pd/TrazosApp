import 'package:cloud_functions/cloud_functions.dart';

import 'conquest_feed.dart';
import 'conquest_interaction.dart';
import 'conquest_post.dart';

abstract interface class ConquestFeedRepository {
  Future<ConquestFeedPage> fetchPage({
    ConquestFeedCursor? cursor,
    int limit = 20,
  });

  Future<ConquestFeedItem> fetchDetail(String postId);

  /// Historias activas visibles. Si [userId] no es null, solo de ese corredor.
  Future<List<ConquestFeedItem>> fetchStories({int limit = 20, String? userId});
}

class CallableConquestFeedRepository implements ConquestFeedRepository {
  CallableConquestFeedRepository({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  @override
  Future<ConquestFeedPage> fetchPage({
    ConquestFeedCursor? cursor,
    int limit = 20,
  }) async {
    final result = await _functions.httpsCallable('getConquestFeed').call({
      'limit': limit.clamp(1, 30),
      if (cursor != null)
        'cursor': {
          'createdAtSeconds': cursor.createdAtSeconds,
          'createdAtNanoseconds': cursor.createdAtNanoseconds,
          'id': cursor.id,
        },
    });
    final data = _asMap(result.data);
    final items = (data['items'] as List? ?? const [])
        .map((item) => _itemFromMap(_asMap(item)))
        .toList(growable: false);
    final cursorData = data['nextCursor'];
    return ConquestFeedPage(
      items: items,
      hasMore: data['hasMore'] as bool? ?? false,
      nextCursor:
          cursorData == null ? null : _cursorFromMap(_asMap(cursorData)),
    );
  }

  @override
  Future<ConquestFeedItem> fetchDetail(String postId) async {
    final result = await _functions
        .httpsCallable('getConquestDetail')
        .call({'postId': postId});
    final data = _asMap(result.data);
    return _itemFromMap(_asMap(data['item']));
  }

  @override
  Future<List<ConquestFeedItem>> fetchStories({
    int limit = 20,
    String? userId,
  }) async {
    final result = await _functions.httpsCallable('getConquestStories').call({
      'limit': limit.clamp(1, 30),
      if (userId != null && userId.isNotEmpty) 'userId': userId,
    });
    final data = _asMap(result.data);
    return (data['items'] as List? ?? const [])
        .map((item) => _itemFromMap(_asMap(item)))
        .toList(growable: false);
  }

  static ConquestFeedCursor _cursorFromMap(Map<String, dynamic> data) =>
      ConquestFeedCursor(
        createdAtSeconds: (data['createdAtSeconds'] as num).toInt(),
        createdAtNanoseconds: (data['createdAtNanoseconds'] as num).toInt(),
        id: data['id'] as String,
      );

  static ConquestFeedItem _itemFromMap(Map<String, dynamic> data) {
    final post = _postFromMap(_asMap(data['post']));
    final authorData = _asMap(data['author']);
    return ConquestFeedItem(
      post: post,
      author: ConquestAuthor(
        userId: authorData['userId'] as String? ?? post.userId,
        displayName: authorData['displayName'] as String? ?? 'Corredor',
        photoUrl: authorData['photoUrl'] as String?,
      ),
      myReaction: _enumByName(
        ReactionType.values,
        data['myReaction'] as String?,
      ),
    );
  }

  static ConquestPost _postFromMap(Map<String, dynamic> data) => ConquestPost(
        id: data['id'] as String,
        userId: data['userId'] as String,
        type: _enumByName(ConquestType.values, data['type'] as String?) ??
            ConquestType.text,
        visibility: _enumByName(
              ConquestVisibility.values,
              data['visibility'] as String?,
            ) ??
            ConquestVisibility.onlyMe,
        createdAt: _dateFromMs(data['createdAtMs']) ?? DateTime.now(),
        updatedAt: _dateFromMs(data['updatedAtMs']),
        zoneId: data['zoneId'] as String?,
        activityId: data['activityId'] as String?,
        challengeId: data['challengeId'] as String?,
        achievementId: data['achievementId'] as String?,
        caption: data['caption'] as String? ?? '',
        mediaUrl: data['mediaUrl'] as String?,
        thumbnailUrl: data['thumbnailUrl'] as String?,
        expiresAt: _dateFromMs(data['expiresAtMs']),
        isArchived: data['isArchived'] as bool? ?? false,
        isDeleted: data['isDeleted'] as bool? ?? false,
        locationPrivacyMode: _enumByName(
              LocationPrivacyMode.values,
              data['locationPrivacyMode'] as String?,
            ) ??
            LocationPrivacyMode.city,
        zoneNameSnapshot: data['zoneNameSnapshot'] as String? ?? '',
        distanceSnapshot: (data['distanceSnapshot'] as num?)?.toDouble() ?? 0,
        durationSnapshot: (data['durationSnapshot'] as num?)?.toInt() ?? 0,
        paceSnapshot: (data['paceSnapshot'] as num?)?.toDouble() ?? 0,
        elevationSnapshot: (data['elevationSnapshot'] as num?)?.toDouble() ?? 0,
        likesCount: (data['likesCount'] as num?)?.toInt() ?? 0,
        applauseCount: (data['applauseCount'] as num?)?.toInt() ?? 0,
        commentsCount: (data['commentsCount'] as num?)?.toInt() ?? 0,
        reportCount: (data['reportCount'] as num?)?.toInt() ?? 0,
        moderationStatus: data['moderationStatus'] as String? ?? 'ok',
      );

  static DateTime? _dateFromMs(Object? value) =>
      value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt()) : null;

  static T? _enumByName<T extends Enum>(List<T> values, String? name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }

  static Map<String, dynamic> _asMap(Object? value) =>
      Map<String, dynamic>.from(value as Map);
}
