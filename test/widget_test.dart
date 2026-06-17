// Smoke test básico de Trazos.
//
// La app completa (TrazosApp) inicializa Firebase en main(), lo que no es
// posible en un test unitario sin emuladores/mocks. Este test verifica el
// tema y los widgets de forma aislada. Amplíalo con mocks de Firebase
// (p. ej. firebase_auth_mocks) cuando montes la suite de tests.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runrace/core/theme.dart';

void main() {
  testWidgets('El tema de la app se construye y renderiza un widget',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const Scaffold(body: Center(child: Text('Trazos'))),
      ),
    );

    expect(find.text('Trazos'), findsOneWidget);
  });
}
