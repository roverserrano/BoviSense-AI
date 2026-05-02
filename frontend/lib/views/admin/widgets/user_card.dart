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
  });

  final UsuarioModel usuario;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final isAdmin = usuario.rol.toLowerCase() == 'administrador';

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
          ),
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
