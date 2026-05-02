import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminSearchBar extends StatelessWidget {
  const AdminSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Buscar usuario...',
            helperText: 'Nombre, apellido o correo',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Limpiar',
                  )
                : null,
            filled: true,
            fillColor: AdminPalette.card,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AdminPalette.border,
                width: 0.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AdminPalette.border,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AdminPalette.primary,
                width: 1,
              ),
            ),
          ),
        );
      },
    );
  }
}
