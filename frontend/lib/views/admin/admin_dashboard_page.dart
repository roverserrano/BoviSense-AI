import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import 'usuario_form_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsuariosViewModel>().loadUsers();
    });
  }

  Future<void> _openForm([UsuarioModel? usuario]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => UsuarioFormPage(usuario: usuario)),
    );

    if (!mounted) return;

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usuario == null
                ? 'Usuario registrado correctamente.'
                : 'Usuario actualizado correctamente.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(UsuarioModel usuario) async {
    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Eliminar usuario'),
            content: Text('¿Deseas eliminar a ${usuario.nombreCompleto}?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    final vm = context.read<AdminUsuariosViewModel>();
    final ok = await vm.deleteUser(usuario.uid);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Usuario eliminado correctamente.'
              : (vm.errorMessage ?? 'No se pudo eliminar.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<AdminUsuariosViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrador'),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthViewModel>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.isSaving ? null : () => _openForm(),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Nuevo usuario'),
      ),
      body: RefreshIndicator(
        onRefresh: vm.loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  child: Icon(
                    Icons.admin_panel_settings_rounded,
                    color: Colors.white,
                  ),
                ),
                title: Text(
                  'Bienvenido, ${authVm.currentUser?.nombreCompleto ?? 'Administrador'}',
                ),
                subtitle: const Text('Gestión de usuarios del sistema'),
              ),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (vm.isLoading && vm.usuarios.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (vm.usuarios.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.people_outline_rounded,
                        size: 56,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(height: 12),
                      Text('No hay usuarios para mostrar'),
                    ],
                  ),
                ),
              )
            else
              ...vm.usuarios.map(
                (usuario) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: usuario.rol == 'administrador'
                                    ? const Color(0xFF8D6E63)
                                    : const Color(0xFF4CAF50),
                                child: Icon(
                                  usuario.rol == 'administrador'
                                      ? Icons.admin_panel_settings_rounded
                                      : Icons.person_rounded,
                                  color: Colors.white,
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
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(usuario.correo),
                                  ],
                                ),
                              ),
                              Chip(label: Text(usuario.estado)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Chip(
                                label: Text('CI: ${usuario.cedulaIdentidad}'),
                              ),
                              Chip(label: Text('Tel: ${usuario.telefono}')),
                              Chip(label: Text('Rol: ${usuario.rol}')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                onPressed: vm.isSaving
                                    ? null
                                    : () => _openForm(usuario),
                                icon: const Icon(Icons.edit_rounded),
                                label: const Text('Editar'),
                              ),
                              TextButton.icon(
                                onPressed: vm.isSaving
                                    ? null
                                    : () => _confirmDelete(usuario),
                                icon: const Icon(Icons.delete_outline_rounded),
                                label: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
