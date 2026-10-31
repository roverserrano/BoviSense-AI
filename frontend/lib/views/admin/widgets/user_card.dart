import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
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
    final isActive = usuario.estado.toLowerCase() == 'activo';
    final pendiente = (usuario.operacionPendiente ?? '').trim();

    return BoviCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Avatar(isAdmin: isAdmin, isActive: isActive, usuario: usuario),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            usuario.nombreCompleto,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(
                          dot: true,
                          label: isActive ? 'Activo' : 'Desactivado',
                          color: isActive
                              ? AppColors.success
                              : AppColors.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline_rounded,
                          size: 14,
                          color: AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            usuario.correo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Datos de contacto en un contenedor suave, con el rol al extremo.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.call_outlined,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    usuario.telefono > 0
                        ? '${usuario.telefono}'
                        : 'Sin teléfono',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                StatusChip(
                  label: _capitalize(usuario.rol),
                  color: AppColors.muted,
                ),
              ],
            ),
          ),
          if (isSelf || pendiente.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (isSelf)
                  const StatusChip(
                    label: 'Tu cuenta',
                    color: AppColors.primary,
                  ),
                if (pendiente.isNotEmpty)
                  const StatusChip(
                    label: 'Operación pendiente',
                    color: AppColors.danger,
                  ),
              ],
            ),
          ],
          if (!isActive) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: AppColors.warning,
                ),
                SizedBox(width: 6),
                Text(
                  'Cuenta desactivada',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: isBusy ? null : onEdit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.fillDisabled,
                    disabledForegroundColor: AppColors.textDisabled,
                    minimumSize: const Size(double.infinity, 44),
                    textStyle: const TextStyle(
                      fontSize: 14.5,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Editar'),
                      SizedBox(width: 4),
                      Icon(Icons.chevron_right_rounded, size: 19),
                    ],
                  ),
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
}

/// Avatar cuadrado de la tarjeta: iniciales en verde o icono de cuenta
/// desactivada, según el estado.
class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.usuario,
    required this.isAdmin,
    required this.isActive,
  });

  final UsuarioModel usuario;
  final bool isAdmin;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isActive
            ? (isAdmin ? AppColors.primaryDark : AppColors.primary)
            : AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: isActive ? null : Border.all(color: AppColors.border),
      ),
      child: isActive
          ? Text(
              _initials(usuario.nombre, usuario.apellidos),
              style: const TextStyle(
                color: AppColors.onPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            )
          : const Icon(
              Icons.person_off_rounded,
              size: 22,
              color: AppColors.muted,
            ),
    );
  }
}

String _initials(String name, String lastName) {
  final first = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '';
  final second = lastName.trim().isNotEmpty
      ? lastName.trim()[0].toUpperCase()
      : (name.trim().length > 1 ? name.trim()[1].toUpperCase() : 'U');
  return '$first$second';
}

String _capitalize(String value) {
  final text = value.trim();
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}
