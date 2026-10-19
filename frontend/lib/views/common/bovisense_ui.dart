import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';

/// Estado simple usado por las tarjetas y barras de estado.
enum SimpleStatusType { pending, ready, inProgress, finished, error }

String statusLabel(SimpleStatusType status) {
  switch (status) {
    case SimpleStatusType.pending:
      return 'Pendiente';
    case SimpleStatusType.ready:
      return 'Listo';
    case SimpleStatusType.inProgress:
      return 'En curso';
    case SimpleStatusType.finished:
      return 'Terminado';
    case SimpleStatusType.error:
      return 'Error';
  }
}

Color statusColor(SimpleStatusType status) {
  switch (status) {
    case SimpleStatusType.pending:
      return AppColors.muted;
    case SimpleStatusType.ready:
      return AppColors.success;
    case SimpleStatusType.inProgress:
      return AppColors.warning;
    case SimpleStatusType.finished:
      return AppColors.primary;
    case SimpleStatusType.error:
      return AppColors.error;
  }
}

/// Barra superior unificada de la aplicación (fondo verde oscuro).
class AppTopBar extends AppBar {
  AppTopBar({
    super.key,
    required String titleText,
    super.actions,
    super.leading,
    super.bottom,
  }) : super(title: Text(titleText));
}

/// Tarjeta base: superficie blanca, borde suave, radio 16.
class BoviCard extends StatelessWidget {
  const BoviCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = AppRadius.card,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final background = color ?? AppColors.surface;
    final border = borderColor ?? AppColors.border;

    if (onTap == null) {
      return Container(
        padding: padding,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: border),
        ),
        child: child,
      );
    }

    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Encabezado de sección en mayúsculas.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(text.toUpperCase(), style: AppTypography.sectionHeader),
    );
  }
}

/// Etiqueta corta de estado: color semántico + texto (nunca solo color).
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tono de un mensaje de estado.
enum StatusBannerTone { neutral, info, success, warning, error }

/// Mensaje con icono, título y detalle. Base de [AlertCard].
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.title,
    this.description,
    this.tone = StatusBannerTone.neutral,
    this.icon,
    this.action,
  });

  final String title;
  final String? description;
  final StatusBannerTone tone;
  final IconData? icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, toneIcon) = switch (tone) {
      StatusBannerTone.neutral => (
        AppColors.surfaceAlt,
        AppColors.textSecondary,
        Icons.info_outline_rounded,
      ),
      StatusBannerTone.info => (
        AppColors.infoBg,
        AppColors.info,
        Icons.info_outline_rounded,
      ),
      StatusBannerTone.success => (
        AppColors.successBg,
        AppColors.success,
        Icons.check_circle_outline_rounded,
      ),
      StatusBannerTone.warning => (
        AppColors.warningBg,
        AppColors.warning,
        Icons.warning_amber_rounded,
      ),
      StatusBannerTone.error => (
        AppColors.errorBg,
        AppColors.error,
        Icons.error_outline_rounded,
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon ?? toneIcon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                if (description != null && description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: foreground,
                    ),
                  ),
                ],
                if (action != null) ...[const SizedBox(height: 8), action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de aviso usada por las pantallas del ganadero.
class AlertCard extends StatelessWidget {
  const AlertCard({
    super.key,
    required this.title,
    required this.description,
    required this.status,
  });

  final String title;
  final String description;
  final SimpleStatusType status;

  @override
  Widget build(BuildContext context) {
    final tone = switch (status) {
      SimpleStatusType.error => StatusBannerTone.error,
      SimpleStatusType.inProgress => StatusBannerTone.warning,
      SimpleStatusType.pending => StatusBannerTone.neutral,
      SimpleStatusType.ready ||
      SimpleStatusType.finished => StatusBannerTone.success,
    };

    return StatusBanner(title: title, description: description, tone: tone);
  }
}

/// Barra de estado principal: punto de color, etiqueta y subtítulo.
class StatusBar extends StatelessWidget {
  const StatusBar({
    super.key,
    required this.status,
    required this.label,
    required this.subtitle,
  });

  final SimpleStatusType status;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);

    return MergeSemantics(
      child: BoviCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Métrica con número grande, etiqueta y estado.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.number,
    required this.label,
    required this.status,
    this.statusColor = AppColors.primary,
  });

  final String number;
  final String label;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return BoviCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            number,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 10),
          StatusChip(label: status, color: statusColor),
        ],
      ),
    );
  }
}

/// Estado vacío con icono, título, descripción y acción opcional.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return BoviCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Icon(icon, size: 26, color: AppColors.primary),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.caption,
          ),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

/// Acción principal de ancho completo; soporta estado de carga.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: isLoading
            ? ElevatedButton.styleFrom(
                disabledBackgroundColor: AppColors.primary.withValues(
                  alpha: 0.82,
                ),
                disabledForegroundColor: AppColors.onPrimary,
              )
            : null,
        child: isLoading
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(label),
                ],
              )
            : Text(label),
      ),
    );
  }
}

/// Acción secundaria de ancho completo (contorno).
class OutlineActionButton extends StatelessWidget {
  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

/// Acción de detener: tonal roja, sin ser destructiva.
class StopButton extends StatelessWidget {
  const StopButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorBg,
          foregroundColor: AppColors.error,
          disabledBackgroundColor: AppColors.fillDisabled,
          disabledForegroundColor: AppColors.textDisabled,
        ),
        child: Text(label),
      ),
    );
  }
}

/// Trazas técnicas plegables (monoespaciadas, para datos, no adorno).
class TechnicalDetails extends StatelessWidget {
  const TechnicalDetails({super.key, required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ExpansionTile(
        collapsedIconColor: AppColors.textSecondary,
        iconColor: AppColors.textSecondary,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        children: [
          if (lines.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Sin datos técnicos por ahora.',
                style: AppTypography.technical,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(line, style: AppTypography.technical),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}
