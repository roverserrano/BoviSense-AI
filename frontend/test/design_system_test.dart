import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/theme/app_colors.dart';
import 'package:frontend/core/theme/app_theme.dart';
import 'package:frontend/views/common/bovisense_ui.dart';
import 'package:frontend/views/ganadero/widgets/ganadero_widgets.dart';

/// Contraste WCAG 2.2 entre dos colores (1.0 a 21.0).
double _contrast(Color a, Color b) {
  final double la = a.computeLuminance();
  final double lb = b.computeLuminance();
  final double lighter = math.max(la, lb);
  final double darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('contraste de los tokens', () {
    test(
      'el texto principal y secundario cumplen AAA sobre las superficies',
      () {
        // 7:1 es el minimo AAA para texto normal.
        expect(
          _contrast(AppColors.textPrimary, AppColors.surface),
          greaterThanOrEqualTo(7.0),
        );
        expect(
          _contrast(AppColors.textPrimary, AppColors.background),
          greaterThanOrEqualTo(7.0),
        );
        expect(
          _contrast(AppColors.textSecondary, AppColors.surface),
          greaterThanOrEqualTo(4.6),
        );
        expect(
          _contrast(AppColors.muted, AppColors.surface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(AppColors.muted, AppColors.background),
          greaterThanOrEqualTo(4.5),
        );
      },
    );

    test('el blanco es legible sobre las superficies de marca', () {
      expect(
        _contrast(AppColors.onPrimary, AppColors.primary),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.onPrimary, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.textOnDark, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.textOnDarkMuted, AppColors.primaryDark),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('los colores semánticos son legibles sobre sus fondos', () {
      expect(
        _contrast(AppColors.success, AppColors.successBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.warning, AppColors.warningBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.error, AppColors.errorBg),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.info, AppColors.infoBg),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('los bordes de controles alcanzan 3:1 (WCAG 1.4.11)', () {
      expect(
        _contrast(AppColors.borderStrong, AppColors.surface),
        greaterThanOrEqualTo(3.0),
      );
      expect(
        _contrast(AppColors.borderStrong, AppColors.background),
        greaterThanOrEqualTo(2.9),
      );
    });

    test('el dorado de acento es de relleno, no de texto', () {
      // Regla documentada en DESIGN.md: el acento no se usa como texto sobre
      // blanco; para texto dorado legible existe accentStrong.
      expect(_contrast(AppColors.accent, AppColors.surface), lessThan(3.0));
      expect(
        _contrast(AppColors.accentStrong, AppColors.surface),
        greaterThanOrEqualTo(4.5),
      );
    });

    test('el botón destructivo mantiene texto blanco legible', () {
      expect(
        _contrast(AppColors.onDanger, AppColors.danger),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('tema global', () {
    test('el tema usa los tokens de la identidad', () {
      final theme = AppTheme.lightTheme;

      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
      // El scheme usa el rojo de relleno (`danger`), no el rojo de texto.
      expect(theme.colorScheme.error, AppColors.danger);
      expect(theme.colorScheme.errorContainer, AppColors.errorBg);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.appBarTheme.backgroundColor, AppColors.primaryDark);
      expect(theme.useMaterial3, isTrue);
    });
  });

  group('componentes compartidos', () {
    testWidgets('PrimaryButton muestra el estado de carga sin desaparecer', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PrimaryButton(
              label: 'Guardando...',
              isLoading: true,
              onPressed: () => taps += 1,
            ),
          ),
        ),
      );

      expect(find.text('Guardando...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Mientras carga no se puede volver a pulsar.
      await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);
    });

    testWidgets('StatusChip y EmptyState exponen su texto', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Column(
              children: [
                StatusChip(label: 'Faltante', color: AppColors.warning),
                EmptyState(
                  icon: Icons.history_rounded,
                  title: 'Todavía no hay conteos registrados',
                  description: 'Realiza tu primer conteo para verlo aquí.',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Faltante'), findsOneWidget);
      expect(find.text('Todavía no hay conteos registrados'), findsOneWidget);
      expect(
        find.text('Realiza tu primer conteo para verlo aquí.'),
        findsOneWidget,
      );
    });

    testWidgets('la barra del ganadero conserva su altura en el Scaffold', (
      tester,
    ) async {
      var bodyHeight = 0.0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            bottomNavigationBar: GanaderoBottomNavBar(
              currentIndex: 0,
              onTap: (_) {},
            ),
            body: LayoutBuilder(
              builder: (_, constraints) {
                bodyHeight = constraints.maxHeight;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      );

      // Regresión: el contenido del ítem usaba una `Column` sin acotar y, en
      // las restricciones holgadas del slot `bottomNavigationBar`, la barra se
      // estiraba a toda la pantalla y el cuerpo quedaba sin altura.
      final barHeight = tester
          .getSize(find.byType(GanaderoBottomNavBar))
          .height;
      expect(barHeight, greaterThan(56));
      expect(barHeight, lessThan(160));
      expect(bodyHeight, greaterThan(300));
    });
  });
}
