import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AdminFilterType { all, active, inactive, admins }

/// Filtros del listado de usuarios.
///
/// El estado seleccionado no depende solo del color: el chip activo también
/// cambia de fondo y peso de texto, y expone `selected` a los lectores de
/// pantalla. Cada chip muestra el total real de cuentas de su categoría
/// ([counts]); el número acompaña a la etiqueta, no la reemplaza.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
    this.counts = const {},
  });

  final AdminFilterType selected;
  final ValueChanged<AdminFilterType> onSelected;

  /// Totales por filtro. Los filtros sin entrada no muestran contador.
  final Map<AdminFilterType, int> counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Todos', AdminFilterType.all),
          const SizedBox(width: 8),
          _chip('Activos', AdminFilterType.active, dotColor: AppColors.success),
          const SizedBox(width: 8),
          _chip(
            'Inactivos',
            AdminFilterType.inactive,
            dotColor: AppColors.warning,
          ),
          const SizedBox(width: 8),
          _chip('Admin', AdminFilterType.admins, dotColor: AppColors.primary),
        ],
      ),
    );
  }

  Widget _chip(String label, AdminFilterType value, {Color? dotColor}) {
    final isActive = selected == value;
    final count = counts[value];

    return Semantics(
      button: true,
      selected: isActive,
      label: count == null
          ? 'Filtrar por $label'
          : 'Filtrar por $label ($count)',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelected(value),
        child: Padding(
          // Relleno vertical para alcanzar el minimo tactil de 48 dp.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.borderStrong,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (dotColor != null) ...[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive
                        ? AppColors.onPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 1.5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.onPrimary.withValues(alpha: 0.22)
                          : AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.onPrimary : AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
