import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/config/app_config.dart';
import 'package:frontend/views/common/app_splash_screen.dart';
import 'package:frontend/views/common/session_actions.dart';

void main() {
  group('splash', () {
    test('waits for the session but never hangs', () {
      // Inicializacion lenta: se sale al llegar al maximo.
      expect(
        AppSplashScreen.isReady(
          minimumElapsed: true,
          maximumElapsed: false,
          initializing: true,
        ),
        isFalse,
      );
      expect(
        AppSplashScreen.isReady(
          minimumElapsed: true,
          maximumElapsed: true,
          initializing: true,
        ),
        isTrue,
      );
      // El minimo se respeta aunque la sesion ya este lista.
      expect(
        AppSplashScreen.isReady(
          minimumElapsed: false,
          maximumElapsed: false,
          initializing: false,
        ),
        isFalse,
      );
      expect(
        AppSplashScreen.isReady(
          minimumElapsed: true,
          maximumElapsed: false,
          initializing: false,
        ),
        isTrue,
      );
    });
  });

  group('support contact', () {
    test('the whatsapp link is built with encoded message', () {
      final uri = AppConfig.supportWhatsappUri;

      expect(uri.scheme, 'whatsapp');
      expect(uri.host, 'send');
      expect(uri.queryParameters['phone'], AppConfig.supportWhatsappNumber);
      expect(uri.queryParameters['text'], AppConfig.supportWhatsappMessage);
      // Sin signos ni espacios sin codificar en la URI final.
      expect(uri.toString(), isNot(contains(' ')));
      expect(uri.toString(), contains('phone=59171338567'));
    });
  });

  group('logout', () {
    testWidgets('asks for confirmation before closing the session', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(appBar: AppBar(actions: const [SessionActionsMenu()])),
        ),
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('¿Cerrar sesión?'), findsOneWidget);
      expect(
        find.text('Tendrás que volver a ingresar tu correo y contraseña.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('¿Cerrar sesión?'), findsNothing);
    });
  });
}
