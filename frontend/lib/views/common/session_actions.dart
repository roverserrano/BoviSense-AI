import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../auth/cambiar_contrasena_page.dart';
import '../auth_gate.dart';

class SessionActionsMenu extends StatelessWidget {
  const SessionActionsMenu({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    await context.read<AuthViewModel>().logout();
    if (!context.mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (_) => false,
    );
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
