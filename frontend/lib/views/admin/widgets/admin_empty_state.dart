import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    this.title = 'Sin resultados',
    this.description = 'No encontramos usuarios con los filtros actuales.',
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AdminPalette.inactiveBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.group_off_rounded,
              color: AdminPalette.inactiveText,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AdminPalette.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AdminPalette.muted),
          ),
        ],
      ),
    );
  }
}
