import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../common/bovisense_ui.dart';
import '../common/exit_confirm.dart';
import '../common/session_actions.dart';
import 'usuario_form_page.dart';
import 'widgets/admin_search_bar.dart';
import 'widgets/delete_confirm_dialog.dart';
import 'widgets/filter_chip_row.dart';
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
        appBar: AppTopBar(
          titleText: 'Panel de administración',
          actions: const [SessionActionsMenu()],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: vm.isSaving ? null : () => _openForm(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Nuevo usuario'),
        ),
        body: RefreshIndicator(
          onRefresh: vm.loadUsers,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primaryLight,
                    child: const Icon(
                      Icons.person_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hola, ${authVm.currentUser?.nombreCorto ?? 'Administrador'}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          authVm.currentUser?.rol ?? 'administrador',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                const SizedBox(height: 12),
                Text(
                  '${vm.resumen!.total} usuarios · '
                  '${vm.resumen!.activos} activos · '
                  '${vm.resumen!.inactivos} inactivos · '
                  '${vm.resumen!.administradores} admin',
                  style: AppTypography.caption,
                ),
                const SizedBox(height: 8),
              ] else
                const SizedBox(height: 14),
              const SectionTitle(text: 'Usuarios registrados'),
              if (vm.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: StatusBanner(
                    title: vm.errorMessage!,
                    tone: StatusBannerTone.error,
                  ),
                ),
              if (vm.isLoading && usuarios.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Center(
                    child: Semantics(
                      label: 'Cargando usuarios',
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  ),
                )
              else if (usuariosFiltrados.isEmpty)
                EmptyState(
                  icon: Icons.group_off_rounded,
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
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: vm.isLoading
                        ? null
                        : () => vm.loadUsers(more: true),
                    icon: const Icon(Icons.expand_more_rounded),
                    label: Text(
                      vm.isLoading ? 'Cargando...' : 'Cargar mas usuarios',
                    ),
                  ),
                ),
              if (vm.hasMore)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'La búsqueda recorre los usuarios cargados; usa "Cargar más usuarios" para ver el resto.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: AppColors.muted,
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
