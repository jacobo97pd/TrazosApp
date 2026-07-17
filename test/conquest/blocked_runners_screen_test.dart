import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runrace/models/user_model.dart';
import 'package:runrace/screens/blocked_runners_screen.dart';
import 'package:runrace/social/runner_connection.dart';
import 'package:runrace/social/social_providers.dart';

void main() {
  final now = DateTime(2026, 7, 17, 12);

  RunnerConnection blocked({
    required String otherUserId,
    required String blockedBy,
    Set<String> blockedByUsers = const {},
  }) =>
      RunnerConnection(
        id: RunnerConnection.idFor('me', otherUserId),
        requesterUserId: 'me',
        recipientUserId: otherUserId,
        status: ConnectionStatus.blocked,
        source: ConnectionSource.username,
        createdAt: now,
        updatedAt: now,
        blockedAt: now,
        blockedBy: blockedBy,
        blockedByUsers: blockedByUsers,
      );

  Future<void> pumpScreen(
    WidgetTester tester,
    List<RunnerConnection> connections,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          myConnectionsProvider.overrideWith(
            (_) => Stream.value(connections),
          ),
          userModelProvider.overrideWith(
            (_, userId) async => UserModel(
              uid: userId,
              displayName: userId == 'runner-1' ? 'Ana Runner' : 'Otro Runner',
              email: '',
            ),
          ),
        ],
        child: const MaterialApp(
          home: BlockedRunnersScreen(currentUserId: 'me'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista solo los bloqueos iniciados por el usuario',
      (tester) async {
    await pumpScreen(tester, [
      blocked(otherUserId: 'runner-1', blockedBy: 'me'),
      blocked(otherUserId: 'runner-2', blockedBy: 'runner-2'),
    ]);

    expect(find.text('Ana Runner'), findsOneWidget);
    expect(find.text('Otro Runner'), findsNothing);
    expect(find.text('Desbloquear'), findsOneWidget);
  });

  testWidgets('confirma antes de desbloquear', (tester) async {
    await pumpScreen(
      tester,
      [blocked(otherUserId: 'runner-1', blockedBy: 'me')],
    );

    await tester.tap(find.text('Desbloquear'));
    await tester.pumpAndSettle();
    expect(find.text('¿Desbloquear a Ana Runner?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Desbloquear a Ana Runner?'), findsNothing);
  });

  testWidgets('muestra estado vacio si el otro usuario inicio el bloqueo',
      (tester) async {
    await pumpScreen(
      tester,
      [blocked(otherUserId: 'runner-2', blockedBy: 'runner-2')],
    );

    expect(find.text('No has bloqueado a ningún corredor'), findsOneWidget);
  });

  testWidgets('mantiene visible un bloqueo mutuo iniciado por el usuario',
      (tester) async {
    await pumpScreen(tester, [
      blocked(
        otherUserId: 'runner-1',
        blockedBy: 'runner-1',
        blockedByUsers: {'runner-1', 'me'},
      ),
    ]);

    expect(find.text('Ana Runner'), findsOneWidget);
    expect(find.text('Desbloquear'), findsOneWidget);
  });
}
