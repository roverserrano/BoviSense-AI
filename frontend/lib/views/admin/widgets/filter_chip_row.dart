import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

enum AdminFilterType { all, active, inactive, admins }

/// Filtros del listado de usuarios.
///
/// El estado seleccionado no depende solo del color: el chip activo también
/// cambia de fondo y peso de texto, y expone `selected` a los lectores de
/// pantalla.
class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final AdminFilterType selected;
  final ValueChanged<AdminFilterType> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _chip('Todos', AdminFilterType.all),
          const SizedBox(width: 8),
          _chip('Activos', AdminFilterType.active),
          const SizedBox(width: 8),
          _chip('Inactivos', AdminFilterType.inactive),
          const SizedBox(width: 8),
          _chip('Admin', AdminFilterType.admins),
        ],
      ),
    );
  }

  Widget _chip(String label, AdminFilterType value) {
    final isActive = selected == value;

    return Semantics(
      button: true,
      selected: isActive,
      label: 'Filtrar por $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelected(value),
        child: Padding(
          // Relleno vertical para alcanzar el minimo tactil de 48 dp.
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: isActive ? AppColors.primary : AppColors.borderStrong,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? AppColors.onPrimary : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
