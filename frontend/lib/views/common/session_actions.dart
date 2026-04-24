import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../auth/cambiar_contrasena_page.dart';

class SessionActionsMenu extends StatelessWidget {
  const SessionActionsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SessionAction>(
      tooltip: 'Opciones de sesión',
      onSelected: (action) {
        if (action == _SessionAction.changePassword) {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CambiarContrasenaPage()),
          );
          return;
        }

        context.read<AuthViewModel>().logout();
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
