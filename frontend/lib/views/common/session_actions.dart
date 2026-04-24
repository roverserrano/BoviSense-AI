import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';

class SessionActionsMenu extends StatelessWidget {
  const SessionActionsMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SessionAction>(
      tooltip: 'Opciones de sesión',
      onSelected: (action) {
        if (action == _SessionAction.changePassword) {
          showDialog<void>(
            context: context,
            builder: (_) => const _ChangePasswordDialog(),
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

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirmar = true;

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.changePassword(
      currentPassword: _actualCtrl.text.trim(),
      newPassword: _nuevaCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vm.errorMessage ?? 'No se pudo actualizar la contraseña.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();

    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _actualCtrl,
              obscureText: _obscureActual,
              decoration: InputDecoration(
                labelText: 'Contraseña actual',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureActual = !_obscureActual);
                  },
                  icon: Icon(
                    _obscureActual
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa tu contraseña actual';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _nuevaCtrl,
              obscureText: _obscureNueva,
              decoration: InputDecoration(
                labelText: 'Nueva contraseña',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureNueva = !_obscureNueva);
                  },
                  icon: Icon(
                    _obscureNueva
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa una nueva contraseña';
                }
                if (value.trim().length < 6) {
                  return 'Debe tener al menos 6 caracteres';
                }
                if (value.trim() == _actualCtrl.text.trim()) {
                  return 'La nueva contraseña debe ser distinta';
                }
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _confirmarCtrl,
              obscureText: _obscureConfirmar,
              decoration: InputDecoration(
                labelText: 'Confirmar nueva contraseña',
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _obscureConfirmar = !_obscureConfirmar);
                  },
                  icon: Icon(
                    _obscureConfirmar
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Confirma la nueva contraseña';
                }
                if (value.trim() != _nuevaCtrl.text.trim()) {
                  return 'Las contraseñas no coinciden';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: vm.isChangingPassword
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: vm.isChangingPassword ? null : _submit,
          child: vm.isChangingPassword
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
