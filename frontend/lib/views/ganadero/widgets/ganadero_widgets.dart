import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/alerta_model.dart';
import '../../../data/models/conteo_model.dart';
import '../../common/bovisense_ui.dart';

/// Estado de un paso del flujo de conteo.
enum StepStateType { completed, active, pending }

/// Tarjeta de siguiente paso: fondo de marca, una sola acción clara.
class NextStepCard extends StatelessWidget {
  const NextStepCard({
    super.key,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  size: 19,
                  color: AppColors.accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textOnDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColors.textOnDarkMuted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(64, 48),
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: Text(buttonText),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila del historial de conteos.
class HistoryItem extends StatelessWidget {
  const HistoryItem({super.key, required this.conteo, this.onTap});

  final ConteoModel conteo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final diff = conteo.diferencia;
    final Color color;
    final String status;

    if (diff == 0) {
      color = AppColors.success;
      status = 'Exacto';
    } else if (diff < 0) {
      color = AppColors.warning;
      status = 'Faltante';
    } else {
      color = AppColors.error;
      status = 'Excedente';
    }

    return BoviCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDateTime(conteo.fechaHoraInicio),
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  // El modelo no tiene lote: se muestra el estado real del
                  // conteo, no un texto genérico.
                  conteo.estadoConteo.trim().isEmpty
                      ? 'Conteo'
                      : _capitalize(conteo.estadoConteo),
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Real ${conteo.cantidadDetectada} / Esperado ${conteo.cantidadEsperada}',
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                diff > 0 ? '+$diff' : '$diff',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                  color: color,
                  fontFeatures: AppTypography.tabularFigures,
                ),
              ),
              const SizedBox(height: 5),
              StatusChip(label: status, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

String _capitalize(String value) {
  final text = value.trim();
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

/// Paso del flujo de conteo con estado visual y acción opcional.
class StepFlowItem extends StatelessWidget {
  const StepFlowItem({
    super.key,
    required this.title,
    required this.description,
    required this.state,
    this.requiredAction,
    this.onTap,
  });

  final String title;
  final String description;
  final StepStateType state;
  final String? requiredAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget indicator;
    switch (state) {
      case StepStateType.completed:
        indicator = Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
        );
      case StepStateType.active:
        indicator = Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.accent, width: 1.6),
          ),
          child: const Center(
            child: SizedBox(
              width: 9,
              height: 9,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      case StepStateType.pending:
        indicator = Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: AppColors.surfaceAlt,
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: SizedBox(
              width: 8,
              height: 8,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.textDisabled,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
    }

    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: indicator),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(description, style: AppTypography.caption),
                if (requiredAction != null &&
                    requiredAction!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    requiredAction!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
            ),
        ],
      ),
    );

    return BoviCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      color: state == StepStateType.active
          ? AppColors.primaryLight
          : AppColors.surface,
      borderColor: state == StepStateType.active
          ? AppColors.primary
          : AppColors.border,
      child: content,
    );
  }
}

/// Resultado del conteo: número protagonista y métricas de comparación.
class ResultHero extends StatelessWidget {
  const ResultHero({
    super.key,
    required this.value,
    required this.unit,
    required this.expected,
    required this.diff,
    required this.status,
  });

  final int value;
  final String unit;
  final int expected;
  final int diff;
  final String status;

  @override
  Widget build(BuildContext context) {
    return BoviCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$value',
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ),
          const SizedBox(height: 6),
          Text(unit, style: AppTypography.caption),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              _heroMetric('Esperados', '$expected'),
              _heroMetric('Diferencia', diff > 0 ? '+$diff' : '$diff'),
              _heroMetric('Estado', status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.25,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Navegación inferior del ganadero (4 destinos).
class GanaderoBottomNavBar extends StatelessWidget {
  const GanaderoBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    const items = [
      (
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Inicio',
      ),
      (icon: Icons.map_outlined, activeIcon: Icons.map_rounded, label: 'Finca'),
      (
        icon: Icons.play_circle_outline_rounded,
        activeIcon: Icons.play_circle_rounded,
        label: 'Conteo',
      ),
      (
        icon: Icons.history_rounded,
        activeIcon: Icons.history_rounded,
        label: 'Historial',
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              offset: Offset(0, 4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _GanaderoNavItem(
                  icon: items[i].icon,
                  activeIcon: items[i].activeIcon,
                  label: items[i].label,
                  selected: currentIndex == i,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GanaderoNavItem extends StatelessWidget {
  const _GanaderoNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.muted;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryLight : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, size: 23, color: color),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.2,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de una alerta (faltante o excedente) del historial.
class AlertItem extends StatelessWidget {
  const AlertItem({super.key, required this.alerta, this.onMarkRead});

  final AlertaModel alerta;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    final level = alerta.nivel.toLowerCase();
    final Color color = switch (level) {
      'alta' => AppColors.error,
      'baja' => AppColors.success,
      _ => AppColors.warning,
    };
    final String tipo = alerta.mensaje.toLowerCase().contains('excedente')
        ? 'Excedente'
        : 'Faltante';

    return BoviCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusChip(label: tipo, color: color),
              const SizedBox(width: 6),
              StatusChip(
                label: 'Nivel ${alerta.nivel}',
                color: AppColors.muted,
              ),
              const Spacer(),
              if (!alerta.leida)
                const Text(
                  'Nueva',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            alerta.mensaje,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          Text(formatDateTime(alerta.fechaHora), style: AppTypography.caption),
          if (!alerta.leida && onMarkRead != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: onMarkRead,
                child: const Text('Marcar como leída'),
              ),
            ),
        ],
      ),
    );
  }
}
