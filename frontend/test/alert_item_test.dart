import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/alerta_model.dart';
import 'package:frontend/views/ganadero/widgets/ganadero_design_system.dart';

AlertaModel alerta({required bool leida, String nivel = 'alta'}) {
  return AlertaModel(
    id: 'alerta-1',
    mensaje:
        'Se detectó un faltante de 3 animales respecto a la cantidad esperada.',
    fechaHora: DateTime(2026, 9, 22, 10, 30),
    leida: leida,
    nivel: nivel,
  );
}

Future<void> pumpAlert(
  WidgetTester tester,
  AlertaModel model,
  VoidCallback? onMarkRead,
) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: AlertItem(alerta: model, onMarkRead: onMarkRead),
      ),
    ),
  );
}

void main() {
  testWidgets('an unread alert can be marked as read', (tester) async {
    var marked = 0;
    await pumpAlert(tester, alerta(leida: false), () => marked += 1);

    expect(find.text('Nueva'), findsOneWidget);
    expect(find.text('Faltante'), findsOneWidget);
    expect(find.text('Nivel alta'), findsOneWidget);
    expect(find.textContaining('faltante de 3'), findsOneWidget);
    expect(find.text('22/09/2026 10:30'), findsOneWidget);

    await tester.tap(find.text('Marcar como leída'));
    await tester.pump();
    expect(marked, 1);
  });

  testWidgets('a read alert hides the action', (tester) async {
    await pumpAlert(
      tester,
      AlertaModel(
        id: 'alerta-2',
        mensaje:
            'Se detectó un excedente de 2 animales respecto a lo esperado.',
        fechaHora: DateTime(2026, 9, 21, 8, 5),
        leida: true,
        nivel: 'baja',
      ),
      null,
    );

    expect(find.text('Excedente'), findsOneWidget);
    expect(find.text('Nivel baja'), findsOneWidget);
    expect(find.text('Nueva'), findsNothing);
    expect(find.text('Marcar como leída'), findsNothing);
  });
}
