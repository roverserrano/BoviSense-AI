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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Column(
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AdminPalette.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      usuario.correo,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminPalette.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _stateBadge(usuario.estado),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaChip('CI: ${usuario.cedulaIdentidad}'),
              _metaChip('Tel: ${usuario.telefono}'),
              _roleBadge(usuario.rol),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
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
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isBusy ? null : onDelete,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
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
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Eliminar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AdminPalette.chipBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: AdminPalette.textPrimary),
      ),
    );
  }

  Widget _roleBadge(String rol) {
    final label = rol.toLowerCase() == 'administrador'
        ? 'Rol: Admin'
        : 'Rol: Usuario';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AdminPalette.activeBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: AdminPalette.activeText,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _stateBadge(String estado) {
    final isActive = estado.toLowerCase() == 'activo';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? AdminPalette.activeBg : AdminPalette.inactiveBg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        estado,
        style: TextStyle(
          fontSize: 11,
          color: isActive ? AdminPalette.activeText : AdminPalette.inactiveText,
          fontWeight: FontWeight.w500,
        ),
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
