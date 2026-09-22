import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/views/common/exit_confirm.dart';

void main() {
  testWidgets('the back button asks for confirmation before closing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ExitConfirmGuard(child: Scaffold(body: Text('Panel'))),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('¿Salir de BoviSense?'), findsOneWidget);
    expect(find.text('¿Quieres cerrar la aplicación?'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);
    expect(find.text('Salir'), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir de BoviSense?'), findsNothing);
    expect(find.text('Panel'), findsOneWidget);
  });

  testWidgets('the screen can handle back itself without asking', (
    tester,
  ) async {
    var handled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ExitConfirmGuard(
          onBack: () async {
            handled += 1;
            return true;
          },
          child: Scaffold(body: Text('Panel')),
        ),
      ),
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, 1);
    expect(find.text('¿Salir de BoviSense?'), findsNothing);
  });
}
