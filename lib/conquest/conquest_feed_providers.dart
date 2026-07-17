import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conquest_feed.dart';
import 'conquest_feed_repository.dart';
import 'conquest_interaction.dart';

final conquestFeedRepositoryProvider = Provider<ConquestFeedRepository>(
  (_) => CallableConquestFeedRepository(),
);

class ConquestFeedState {
  const ConquestFeedState({
    required this.items,
    required this.hasMore,
    this.nextCursor,
    this.isLoadingMore = false,
  });

  final List<ConquestFeedItem> items;
  final ConquestFeedCursor? nextCursor;
  final bool hasMore;
  final bool isLoadingMore;

  ConquestFeedState copyWith({
    List<ConquestFeedItem>? items,
    ConquestFeedCursor? nextCursor,
    bool clearCursor = false,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      ConquestFeedState(
        items: items ?? this.items,
        nextCursor: clearCursor ? null : nextCursor ?? this.nextCursor,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class ConquestFeedController
    extends AutoDisposeAsyncNotifier<ConquestFeedState> {
  static const _pageSize = 20;
  static const _policy = ConquestFeedPolicy();
  int _generation = 0;
  bool _loadingMore = false;
  bool _disposed = false;

  @override
  Future<ConquestFeedState> build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return _firstPage();
  }

  Future<ConquestFeedState> _firstPage() async {
    final page = await ref
        .read(conquestFeedRepositoryProvider)
        .fetchPage(limit: _pageSize);
    return ConquestFeedState(
      items: page.items,
      nextCursor: page.nextCursor,
      hasMore: page.hasMore,
    );
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    _loadingMore = false;
    final previous = state.valueOrNull;
    if (previous == null) state = const AsyncLoading();
    final refreshed = await AsyncValue.guard(_firstPage);
    if (!_disposed && generation == _generation) {
      state = refreshed.hasError && previous != null
          ? AsyncData(previous)
          : refreshed;
    }
  }

  void applyReaction(
    String postId,
    SetConquestReactionResult result,
  ) {
    final current = state.valueOrNull;
    if (current == null) return;
    final items = [
      for (final item in current.items)
        if (item.post.id == postId)
          item.copyWith(
            post: item.post.copyWith(
              likesCount: result.likesCount,
              applauseCount: result.applauseCount,
            ),
            myReaction: result.reaction,
            clearReaction: result.reaction == null,
          )
        else
          item,
    ];
    state = AsyncData(current.copyWith(items: items));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (_loadingMore ||
        current == null ||
        current.isLoadingMore ||
        !current.hasMore ||
        current.nextCursor == null) {
      return;
    }

    _loadingMore = true;
    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final page = await ref.read(conquestFeedRepositoryProvider).fetchPage(
            cursor: current.nextCursor,
            limit: _pageSize,
          );
      if (_disposed || generation != _generation) return;
      state = AsyncData(ConquestFeedState(
        items: _policy.merge(current.items, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
      ));
    } catch (_) {
      if (!_disposed && generation == _generation) {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
      rethrow;
    } finally {
      if (generation == _generation) _loadingMore = false;
    }
  }
}

final conquestFeedProvider =
    AutoDisposeAsyncNotifierProvider<ConquestFeedController, ConquestFeedState>(
        ConquestFeedController.new);

final conquestDetailProvider =
    FutureProvider.autoDispose.family<ConquestFeedItem, String>((ref, postId) {
  return ref.watch(conquestFeedRepositoryProvider).fetchDetail(postId);
});

final conquestStoriesProvider =
    FutureProvider.autoDispose<List<ConquestFeedItem>>((ref) async {
  final items =
      await ref.watch(conquestFeedRepositoryProvider).fetchStories(limit: 30);
  final now = DateTime.now();
  final active = items
      .where((item) =>
          item.post.isStory &&
          item.post.expiresAt != null &&
          item.post.expiresAt!.isAfter(now))
      .toList(growable: false);

  if (active.isNotEmpty) {
    final firstExpiry = active
        .map((item) => item.post.expiresAt!)
        .reduce((first, next) => next.isBefore(first) ? next : first);
    final delay = firstExpiry.difference(now) + const Duration(seconds: 1);
    final timer = Timer(delay, ref.invalidateSelf);
    ref.onDispose(timer.cancel);
  }
  return active;
});
