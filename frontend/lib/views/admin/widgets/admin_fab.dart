import 'package:flutter/material.dart';

import 'admin_tokens.dart';

class AdminFAB extends StatelessWidget {
  const AdminFAB({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          elevation: 0,
          backgroundColor: AdminPalette.primary,
          foregroundColor: AdminPalette.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo usuario'),
      ),
    );
  }
}
