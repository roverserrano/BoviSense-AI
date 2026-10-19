import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../data/models/usuario_model.dart';
import '../../common/bovisense_ui.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.usuario,
    required this.onEdit,
    required this.onDelete,
    required this.isBusy,
    this.isSelf = false,
  });

  final UsuarioModel usuario;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isBusy;

  /// Es la cuenta del administrador que esta usando la app.
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final isAdmin = usuario.rol.toLowerCase() == 'administrador';
    final pendiente = (usuario.operacionPendiente ?? '').trim();

    return BoviCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isAdmin
                    ? AppColors.primaryDark
                    : AppColors.primary,
                child: Text(
                  _initials(usuario.nombre, usuario.apellidos),
                  style: const TextStyle(
                    color: AppColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuario.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (isSelf || pendiente.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSelf)
                      const StatusChip(
                        label: 'Tu cuenta',
                        color: AppColors.primary,
                      ),
                    if (pendiente.isNotEmpty) ...[
                      if (isSelf) const SizedBox(height: 4),
                      const StatusChip(
                        label: 'Operación pendiente',
                        color: AppColors.danger,
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 44),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 17),
                  label: const Text('Editar'),
                ),
              ),
              // La propia cuenta no se puede eliminar (el backend lo rechaza).
              if (!isSelf) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onDelete,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 44),
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 17),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ],
          ),
          if (pendiente.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Hay una operación sin terminar. Vuelve a guardar este usuario con los mismos datos para completarla.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                color: AppColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name, String lastName) {
    final first = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '';
    final second = lastName.trim().isNotEmpty
        ? lastName.trim()[0].toUpperCase()
        : (name.trim().length > 1 ? name.trim()[1].toUpperCase() : 'U');
    return '$first$second';
  }
}
