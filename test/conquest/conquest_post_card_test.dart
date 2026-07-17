import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/conquest/conquest_feed.dart';
import 'package:runrace/conquest/conquest_interaction.dart';
import 'package:runrace/conquest/conquest_post.dart';
import 'package:runrace/core/theme.dart';
import 'package:runrace/widgets/conquest_post_card.dart';

void main() {
  ConquestFeedItem item({ReactionType? reaction, bool story = false}) =>
      ConquestFeedItem(
        post: ConquestPost(
          id: 'post-1',
          userId: 'runner-1',
          type: ConquestType.text,
          visibility: ConquestVisibility.public,
          createdAt: DateTime(2026, 7, 17, 12),
          expiresAt: story ? DateTime(2026, 7, 18, 12) : null,
          caption: 'Primera conquista',
          zoneNameSnapshot: 'Centro',
          distanceSnapshot: 5100,
          likesCount: 2,
          applauseCount: 4,
          commentsCount: 3,
        ),
        author: const ConquestAuthor(
          userId: 'runner-1',
          displayName: 'Ana Runner',
        ),
        myReaction: reaction,
      );

  Future<void> pumpCard(
    WidgetTester tester, {
    required ConquestFeedItem item,
    ValueChanged<ReactionType?>? onReaction,
    VoidCallback? onComments,
    VoidCallback? onMore,
  }) =>
      tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: ConquestPostCard(
              item: item,
              onReaction: onReaction,
              onComments: onComments,
              onMore: onMore,
            ),
          ),
        ),
      );

  testWidgets('muestra autor, contenido y contadores', (tester) async {
    await pumpCard(tester, item: item());

    expect(find.text('Ana Runner'), findsOneWidget);
    expect(find.text('Primera conquista'), findsOneWidget);
    expect(find.text('Centro · 5.1 km'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('los botones emiten el estado objetivo de la reaccion',
      (tester) async {
    ReactionType? target;
    await pumpCard(
      tester,
      item: item(),
      onReaction: (value) => target = value,
    );

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    expect(target, ReactionType.like);

    await pumpCard(
      tester,
      item: item(reaction: ReactionType.applause),
      onReaction: (value) => target = value,
    );
    await tester.tap(find.byIcon(Icons.front_hand_rounded));
    expect(target, isNull);
  });

  testWidgets('una historia conserva el menu de mas opciones', (tester) async {
    var opened = false;
    await pumpCard(
      tester,
      item: item(story: true),
      onMore: () => opened = true,
    );

    expect(find.text('Historia'), findsOneWidget);
    expect(find.byIcon(Icons.more_horiz_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    expect(opened, isTrue);
  });

  testWidgets('expone semantica de toggle y avatar sin duplicados',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpCard(
      tester,
      item: item(reaction: ReactionType.like),
      onReaction: (_) {},
    );

    final likeNode = tester.getSemantics(find.bySemanticsLabel('Me gusta, 2'));
    expect(likeNode.flagsCollection.isButton, isTrue);
    expect(likeNode.flagsCollection.isEnabled, Tristate.isTrue);
    expect(likeNode.flagsCollection.isToggled, Tristate.isTrue);
    expect(find.bySemanticsLabel('Avatar de Ana Runner'), findsOneWidget);

    semantics.dispose();
  });
}
