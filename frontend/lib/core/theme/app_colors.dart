import 'package:flutter/material.dart';

/// Tokens de color de BoviSense (identidad agrotech).
///
/// Fuente única de color para toda la aplicación: ninguna pantalla debe
/// declarar colores "a mano". El detalle de uso y los contrastes verificados
/// están en `DESIGN.md` (raíz del repositorio).
abstract final class AppColors {
  // --- Marca ---------------------------------------------------------------
  /// Verde profundo: acciones principales e iconografía de marca.
  static const Color primary = Color(0xFF185441);

  /// Verde muy oscuro: barras superiores y superficies de marca.
  static const Color primaryDark = Color(0xFF10382E);

  /// Verde claro: fondos de selección y contenedores suaves.
  static const Color primaryLight = Color(0xFFE5F0E9);

  /// Dorado de acento: solo relleno, botón sobre fondo oscuro o detalle.
  /// No usar como texto sobre superficies claras (2.3:1).
  static const Color accent = Color(0xFFD4A447);

  /// Dorado legible sobre blanco y superficies claras.
  static const Color accentStrong = Color(0xFF8A6220);

  /// Texto e iconos sobre [primary] o [primaryDark].
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// Texto principal sobre superficies oscuras de marca.
  static const Color textOnDark = Color(0xFFE9F2EC);

  /// Texto secundario sobre superficies oscuras de marca.
  static const Color textOnDarkMuted = Color(0xFFC7D9CF);

  // --- Superficies ---------------------------------------------------------
  static const Color background = Color(0xFFF7F9F6);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF0F4F1);

  /// Bordes de tarjetas y separadores suaves.
  static const Color border = Color(0xFFDCE5DE);

  /// Bordes de controles (campos, chips): ≥ 3:1 vs blanco (WCAG 1.4.11).
  static const Color borderStrong = Color(0xFF788D81);

  /// Separadores internos de tarjetas.
  static const Color divider = Color(0xFFE4EBE5);

  // --- Texto ---------------------------------------------------------------
  static const Color textPrimary = Color(0xFF1B2B22);
  static const Color textSecondary = Color(0xFF46594E);
  static const Color muted = Color(0xFF5A6E61);
  static const Color textDisabled = Color(0xFF75887D);
  static const Color fillDisabled = Color(0xFFE8EFEA);

  // --- Semánticos ----------------------------------------------------------
  static const Color success = Color(0xFF1F6B47);
  static const Color successBg = Color(0xFFE6F4EC);
  static const Color warning = Color(0xFF7A5312);
  static const Color warningBg = Color(0xFFFBF0DA);
  static const Color warningBorder = Color(0xFFD9A648);
  static const Color error = Color(0xFF8C2B24);
  static const Color errorBg = Color(0xFFFBE9E7);
  static const Color info = Color(0xFF17556E);
  static const Color infoBg = Color(0xFFE4F1F7);

  /// Botones destructivos ("Eliminar"): texto blanco sobre este rojo (6.4:1).
  static const Color danger = Color(0xFFA63A2F);
  static const Color onDanger = Color(0xFFFFFFFF);

  // --- Semáforo de estados -------------------------------------------------
  static const Color statusOk = success;
  static const Color statusWorking = warning;
  static const Color statusNeutral = muted;
  static const Color statusError = error;

  // --- Sombra --------------------------------------------------------------
  static const Color shadow = Color(0x1A123126);
}
