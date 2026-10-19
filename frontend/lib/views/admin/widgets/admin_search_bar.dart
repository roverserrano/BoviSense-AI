import 'package:flutter/material.dart';

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
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Buscar usuario...',
            helperText: 'Nombre, apellido, correo o cédula',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Limpiar búsqueda',
                  )
                : null,
          ),
        );
      },
    );
  }
}
