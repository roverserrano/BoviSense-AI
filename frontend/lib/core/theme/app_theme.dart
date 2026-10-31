import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Espaciado base de la interfaz (múltiplos de 4).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radios de esquina de la interfaz.
abstract final class AppRadius {
  static const double control = 12;
  static const double card = 16;
  static const double dialog = 20;
  static const double pill = 999;
}

/// Tema Material 3 de BoviSense.
///
/// Concentra la apariencia de todos los controles (botones, campos, tarjetas,
/// diálogos, chips, avisos). Las pantallas no deben redefinir estos estilos.
class AppTheme {
  static ThemeData get lightTheme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryLight,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accentStrong,
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: AppColors.warningBg,
      onSecondaryContainer: AppColors.warning,
      tertiary: AppColors.info,
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: AppColors.infoBg,
      onTertiaryContainer: AppColors.info,
      error: AppColors.danger,
      onError: AppColors.onDanger,
      errorContainer: AppColors.errorBg,
      onErrorContainer: AppColors.error,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: Color(0xFFFFFFFF),
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.surfaceAlt,
      surfaceContainerHigh: AppColors.primaryLight,
      surfaceContainerHighest: Color(0xFFDCEBE0),
      outline: AppColors.borderStrong,
      outlineVariant: AppColors.border,
      shadow: Color(0x33000000),
      scrim: Color(0x99000000),
      inverseSurface: AppColors.primaryDark,
      onInverseSurface: AppColors.textOnDark,
      inversePrimary: Color(0xFFA8C9A0),
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.textTheme;
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.control),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.divider,
      disabledColor: AppColors.textDisabled,
      hintColor: AppColors.muted,
      splashColor: const Color(0x14185441),
      highlightColor: const Color(0x0F185441),
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: AppColors.textOnDark,
        displayColor: AppColors.textOnDark,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: Color(0x40185441),
        selectionHandleColor: AppColors.primary,
      ),

      // --- Estructura --------------------------------------------------------
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryDark,
        foregroundColor: AppColors.textOnDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        toolbarHeight: 64,
        titleSpacing: 16,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: AppColors.textOnDark,
        ),
        iconTheme: const IconThemeData(color: AppColors.textOnDark, size: 24),
        actionsIconTheme: const IconThemeData(
          color: AppColors.textOnDark,
          size: 24,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.divider,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        subtitleTextStyle: textTheme.bodySmall,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: AppColors.textSecondary,
        collapsedIconColor: AppColors.textSecondary,
        textColor: AppColors.textPrimary,
        collapsedTextColor: AppColors.textPrimary,
        shape: const Border(),
        collapsedShape: const Border(),
      ),

      // --- Controles ---------------------------------------------------------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.fillDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          elevation: 0,
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.fillDisabled,
          disabledForegroundColor: AppColors.textDisabled,
          minimumSize: const Size(64, 48),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDisabled,
          side: const BorderSide(color: AppColors.borderStrong, width: 1.2),
          minimumSize: const Size(64, 52),
          textStyle: textTheme.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 3,
        extendedTextStyle: textTheme.labelLarge?.copyWith(
          color: AppColors.onPrimary,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceAlt,
        selectedColor: AppColors.primaryLight,
        checkmarkColor: AppColors.primary,
        side: const BorderSide(color: AppColors.border),
        shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyLarge?.copyWith(color: AppColors.muted),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.primary,
        ),
        helperStyle: textTheme.bodySmall?.copyWith(fontSize: 12),
        errorStyle: textTheme.bodySmall?.copyWith(
          fontSize: 12.5,
          color: AppColors.error,
        ),
        prefixIconColor: AppColors.muted,
        suffixIconColor: AppColors.muted,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
      ),

      // --- Capas flotantes ---------------------------------------------------
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.dialog),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.dialog),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: AppColors.primaryDark,
        actionTextColor: AppColors.accent,
        contentTextStyle: const TextStyle(
          color: AppColors.textOnDark,
          fontSize: 13.5,
          height: 1.35,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.bodyMedium,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.primaryDark,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          color: AppColors.textOnDark,
          fontSize: 12.5,
          height: 1.3,
        ),
        waitDuration: const Duration(milliseconds: 500),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primaryLight,
        circularTrackColor: AppColors.primaryLight,
      ),
    );
  }
}
