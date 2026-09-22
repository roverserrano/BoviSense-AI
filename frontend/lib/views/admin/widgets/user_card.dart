import 'package:flutter/material.dart';

import '../../../data/models/usuario_model.dart';
import 'admin_tokens.dart';

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

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isAdmin
                    ? AdminPalette.appBar
                    : AdminPalette.primary,
                child: Text(
                  _initials(usuario.nombre, usuario.apellidos),
                  style: const TextStyle(
                    color: AdminPalette.onPrimary,
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AdminPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      usuario.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelf || pendiente.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSelf)
                      const _Tag(
                        text: 'Tu cuenta',
                        color: AdminPalette.primary,
                      ),
                    if (pendiente.isNotEmpty) ...[
                      if (isSelf) const SizedBox(height: 4),
                      const _Tag(
                        text: 'Operación pendiente',
                        color: AdminPalette.danger,
                      ),
                    ],
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 38),
                    elevation: 0,
                    foregroundColor: AdminPalette.primary,
                    side: const BorderSide(
                      color: AdminPalette.primary,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
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
                      minimumSize: const Size(double.infinity, 38),
                      elevation: 0,
                      foregroundColor: AdminPalette.danger,
                      side: const BorderSide(
                        color: AdminPalette.danger,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Eliminar'),
                  ),
                ),
              ],
            ],
          ),
          if (pendiente.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(
              'Hay una operación sin terminar. Vuelve a guardar este usuario con los mismos datos para completarla.',
              style: TextStyle(fontSize: 11, color: AdminPalette.muted),
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

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
