import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../common/exit_confirm.dart';
import '../common/session_actions.dart';
import 'usuario_form_page.dart';
import 'widgets/admin_empty_state.dart';
import 'widgets/admin_fab.dart';
import 'widgets/admin_search_bar.dart';
import 'widgets/admin_tokens.dart';
import 'widgets/delete_confirm_dialog.dart';
import 'widgets/filter_chip_row.dart';
import 'widgets/section_label.dart';
import 'widgets/user_card.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final TextEditingController _searchController = TextEditingController();
  AdminFilterType _selectedFilter = AdminFilterType.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminUsuariosViewModel>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openForm([UsuarioModel? usuario]) async {
    final adminVm = context.read<AdminUsuariosViewModel>();
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<AdminUsuariosViewModel>.value(
          value: adminVm,
          child: UsuarioFormPage(usuario: usuario),
        ),
      ),
    );

    if (!mounted) return;

    if (saved == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            usuario == null
                ? (context.read<AdminUsuariosViewModel>().creationNotice ??
                      'Usuario registrado correctamente.')
                : 'Usuario actualizado correctamente.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(UsuarioModel usuario) async {
    final confirm = await showDeleteConfirmDialog(
      context: context,
      userName: usuario.nombreCompleto,
    );

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

  List<UsuarioModel> _filteredUsers(List<UsuarioModel> source) {
    final query = _searchController.text.trim().toLowerCase();

    return source.where((usuario) {
      final byQuery =
          query.isEmpty ||
          usuario.nombreCompleto.toLowerCase().contains(query) ||
          usuario.correo.toLowerCase().contains(query) ||
          usuario.cedulaIdentidad.toString().contains(query);

      final rol = usuario.rol.toLowerCase();
      final estado = usuario.estado.toLowerCase();

      final byFilter = switch (_selectedFilter) {
        AdminFilterType.all => true,
        AdminFilterType.active => estado == 'activo',
        AdminFilterType.inactive => estado == 'inactivo',
        AdminFilterType.admins => rol == 'administrador',
      };

      return byQuery && byFilter;
    }).toList();
  }

  /// La busqueda es local: al escribir o filtrar se cargan las paginas que
  /// falten para que un usuario de la pagina 2 no quede invisible.
  void _ensureAllUsersLoaded() {
    unawaited(context.read<AdminUsuariosViewModel>().loadRemainingUsers());
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<AdminUsuariosViewModel>();
    final usuarios = vm.usuarios;
    final usuariosFiltrados = _filteredUsers(usuarios);

    // El boton retroceder nativo pide confirmacion antes de cerrar la app.
    return ExitConfirmGuard(
      child: Scaffold(
        backgroundColor: AdminPalette.pageBg,
        appBar: AppBar(
          backgroundColor: AdminPalette.appBar,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 12,
          title: const Text(
            'Panel de administración',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          toolbarHeight: 68,
          actions: const [SessionActionsMenu()],
        ),
        body: RefreshIndicator(
          onRefresh: vm.loadUsers,
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AdminPalette.chipBg,
                        child: const Icon(
                          Icons.person_rounded,
                          color: AdminPalette.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hola, ${authVm.currentUser?.nombreCorto ?? 'Administrador'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AdminPalette.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              authVm.currentUser?.rol ?? 'administrador',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AdminPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  AdminSearchBar(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {});
                      if (_searchController.text.trim().isNotEmpty) {
                        _ensureAllUsersLoaded();
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  FilterChipRow(
                    selected: _selectedFilter,
                    onSelected: (value) {
                      setState(() => _selectedFilter = value);
                      if (value != AdminFilterType.all) {
                        _ensureAllUsersLoaded();
                      }
                    },
                  ),
                  // Resumen en una sola linea discreta: las tarjetas ocupaban
                  // media pantalla y empujaban la lista fuera de vista.
                  if (vm.resumen != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      '${vm.resumen!.total} usuarios · '
                      '${vm.resumen!.activos} activos · '
                      '${vm.resumen!.inactivos} inactivos · '
                      '${vm.resumen!.administradores} admin',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AdminPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ] else
                    const SizedBox(height: 14),
                  const SectionLabel(text: 'Usuarios registrados'),
                  if (vm.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCEBEB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AdminPalette.border,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        vm.errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFF7A2820),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  if (vm.isLoading && usuarios.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 70),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (usuariosFiltrados.isEmpty)
                    AdminEmptyState(
                      title: usuarios.isEmpty
                          ? 'No hay usuarios'
                          : 'Sin coincidencias',
                      description: usuarios.isEmpty
                          ? 'Aún no hay usuarios registrados en el sistema.'
                          : 'Prueba otro nombre, correo o cambia los filtros.',
                    )
                  else
                    ...usuariosFiltrados.map(
                      (usuario) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: UserCard(
                          usuario: usuario,
                          isBusy: vm.isSaving,
                          isSelf: usuario.uid == authVm.currentUser?.uid,
                          onEdit: () => _openForm(usuario),
                          onDelete: () => _confirmDelete(usuario),
                        ),
                      ),
                    ),
                  if (vm.hasMore)
                    TextButton.icon(
                      onPressed: vm.isLoading
                          ? null
                          : () => vm.loadUsers(more: true),
                      icon: const Icon(Icons.expand_more),
                      label: Text(
                        vm.isLoading ? 'Cargando...' : 'Cargar mas usuarios',
                      ),
                    ),
                  if (vm.hasMore)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'La búsqueda recorre los usuarios cargados; usa "Cargar más usuarios" para ver el resto.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AdminPalette.muted,
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: AdminFloatingFab(
                    onPressed: vm.isSaving ? null : () => _openForm(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
