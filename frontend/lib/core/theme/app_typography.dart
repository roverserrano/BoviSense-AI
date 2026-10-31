import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Escala tipográfica única de BoviSense.
///
/// Usa la familia del sistema (Roboto en Android): sin dependencias externas.
/// Los estilos base se aplican desde [ThemeData.textTheme]; los estilos
/// semánticos ([sectionHeader], [technical], etc.) se usan directamente.
abstract final class AppTypography {
  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontSize: 44,
      height: 1.05,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: AppColors.textPrimary,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    displayMedium: TextStyle(
      fontSize: 34,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      color: AppColors.textPrimary,
    ),
    displaySmall: TextStyle(
      fontSize: 28,
      height: 1.1,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    headlineLarge: TextStyle(
      fontSize: 26,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    headlineSmall: TextStyle(
      fontSize: 19,
      height: 1.25,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    titleSmall: TextStyle(
      fontSize: 14.5,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.45,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      height: 1.35,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 15,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textPrimary,
    ),
    labelSmall: TextStyle(
      fontSize: 11.5,
      height: 1.2,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );

  /// Encabezado de sección; el widget lo muestra en mayúsculas.
  static const TextStyle sectionHeader = TextStyle(
    fontSize: 12,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.muted,
  );

  /// Texto auxiliar (fechas, notas al pie, ayudas).
  static const TextStyle caption = TextStyle(
    fontSize: 12.5,
    height: 1.35,
    fontWeight: FontWeight.w400,
    color: AppColors.muted,
  );

  /// Trazas de "Detalles técnicos": monoespaciada, para datos, no adorno.
  static const TextStyle technical = TextStyle(
    fontFamily: 'monospace',
    fontSize: 11.5,
    height: 1.45,
    color: AppColors.textSecondary,
  );

  /// Cifras tabulares para valores que cambian en vivo (conteo).
  static const List<FontFeature> tabularFigures = [
    FontFeature.tabularFigures(),
  ];
}
