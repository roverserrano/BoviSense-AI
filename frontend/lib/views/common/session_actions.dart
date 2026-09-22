import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../auth/cambiar_contrasena_page.dart';

class SessionActionsMenu extends StatelessWidget {
  const SessionActionsMenu({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    // Cerrar sesion obliga a volver a escribir las credenciales: se confirma.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Tendrás que volver a ingresar tu correo y contraseña.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await context.read<AuthViewModel>().logout();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SessionAction>(
      tooltip: 'Opciones de sesión',
      onSelected: (action) async {
        if (action == _SessionAction.changePassword) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CambiarContrasenaPage()),
          );
          return;
        }

        await _handleLogout(context);
      },
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: _SessionAction.changePassword,
          child: Text('Cambiar contraseña'),
        ),
        PopupMenuItem(
          value: _SessionAction.logout,
          child: Text('Cerrar sesión'),
        ),
      ],
    );
  }
}

enum _SessionAction { changePassword, logout }
