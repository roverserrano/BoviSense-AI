import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/data/models/usuario_model.dart';
import 'package:frontend/data/repositories/admin_usuario_repository.dart';
import 'package:frontend/data/services/api_client.dart';
import 'package:frontend/views/admin/widgets/user_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

UsuarioModel usuario({
  String uid = 'u1',
  String rol = 'usuario',
  String? operacionPendiente,
}) {
  return UsuarioModel(
    uid: uid,
    nombre: 'Ana',
    apellidos: 'Perez',
    cedulaIdentidad: 1234567,
    correo: 'ana@example.test',
    telefono: 76543210,
    rol: rol,
    estado: 'activo',
    operacionPendiente: operacionPendiente,
  );
}

Future<void> pumpCard(
  WidgetTester tester, {
  required UsuarioModel model,
  required bool isSelf,
  required VoidCallback onDelete,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: UserCard(
          usuario: model,
          isBusy: false,
          isSelf: isSelf,
          onEdit: () {},
          onDelete: onDelete,
        ),
      ),
    ),
  );
}

void main() {
  test('the greeting shows the first name and the paternal surname', () {
    expect(
      usuario()
          .copyWith(nombre: 'Rover', apellidos: 'Serrano Quiroz')
          .nombreCorto,
      'Rover Serrano',
    );
    expect(
      usuario().copyWith(nombre: 'Ana', apellidos: 'Perez').nombreCorto,
      'Ana Perez',
    );
    expect(
      usuario().copyWith(nombre: 'Ana', apellidos: '   ').nombreCorto,
      'Ana',
    );
    expect(
      usuario().copyWith(nombre: '', apellidos: 'Serrano Quiroz').nombreCorto,
      'Serrano',
    );
  });

  test(
    'the admin repository parses users, the summary and the cursor',
    () async {
      final client = ApiClient.withProviders(
        tokenProvider: () async => 'token',
        uidProvider: () => 'admin-1',
        baseUrl: 'https://example.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              'usuarios': [
                {
                  'uid': 'u1',
                  'nombre': 'Ana',
                  'apellidos': 'Perez',
                  'cedula_identidad': 1234567,
                  'correo': 'ana@example.test',
                  'telefono': 76543210,
                  'rol': 'usuario',
                  'estado': 'activo',
                  'operacion_pendiente': 'update',
                },
              ],
              'next_cursor': 'cursor-1',
              'resumen': {
                'total': 12,
                'activos': 10,
                'inactivos': 2,
                'administradores': 3,
              },
            }),
            200,
          ),
        ),
      );

      final repository = AdminUsuarioRepository(apiClient: client);
      final usuarios = await repository.listarUsuarios();

      expect(usuarios.single.nombre, 'Ana');
      expect(usuarios.single.operacionPendiente, 'update');
      expect(repository.nextCursor, 'cursor-1');
      expect(repository.resumen?.total, 12);
      expect(repository.resumen?.activos, 10);
      expect(repository.resumen?.inactivos, 2);
      expect(repository.resumen?.administradores, 3);
      client.close();
    },
  );

  test('the summary is null when the backend does not send it', () async {
    final client = ApiClient.withProviders(
      tokenProvider: () async => 'token',
      uidProvider: () => 'admin-1',
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'usuarios': [], 'next_cursor': null}),
          200,
        ),
      ),
    );

    final repository = AdminUsuarioRepository(apiClient: client);
    await repository.listarUsuarios();
    expect(repository.resumen, isNull);
    client.close();
  });

  testWidgets('your own account cannot be deleted but can be edited', (
    tester,
  ) async {
    var deleted = 0;
    await pumpCard(
      tester,
      model: usuario(uid: 'me', rol: 'administrador'),
      isSelf: true,
      onDelete: () => deleted += 1,
    );

    expect(find.text('Tu cuenta'), findsOneWidget);
    expect(find.text('Eliminar'), findsNothing);
    expect(find.text('Editar'), findsOneWidget);
    expect(deleted, 0);
  });

  testWidgets(
    'a pending operation is flagged and other accounts can be deleted',
    (tester) async {
      var deleted = 0;
      await pumpCard(
        tester,
        model: usuario(operacionPendiente: 'update'),
        isSelf: false,
        onDelete: () => deleted += 1,
      );

      expect(find.text('Operación pendiente'), findsOneWidget);
      expect(
        find.textContaining('Vuelve a guardar este usuario'),
        findsOneWidget,
      );

      await tester.tap(find.text('Eliminar'));
      await tester.pump();
      expect(deleted, 1);
    },
  );
}
