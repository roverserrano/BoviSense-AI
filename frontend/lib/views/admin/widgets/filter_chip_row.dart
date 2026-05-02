import 'package:flutter/material.dart';

import 'admin_tokens.dart';

enum AdminFilterType { all, active, inactive, admins }

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onSelected(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AdminPalette.primary : AdminPalette.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isActive ? AdminPalette.primary : AdminPalette.border,
              width: 0.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isActive
                  ? AdminPalette.onPrimary
                  : AdminPalette.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
