import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/admin_resumen_model.dart';
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

  /// Totales para las tarjetas y los contadores de los filtros: el backend
  /// manda los definitivos ([AdminResumenModel]); si no vienen, se cuentan
  /// los usuarios cargados.
  ({int total, int activos, int inactivos, int administradores}) _resumen(
    List<UsuarioModel> usuarios,
    AdminResumenModel? real,
  ) {
    if (real != null) {
      return (
        total: real.total,
        activos: real.activos,
        inactivos: real.inactivos,
        administradores: real.administradores,
      );
    }

    int count(bool Function(UsuarioModel) test) => usuarios.where(test).length;
    return (
      total: usuarios.length,
      activos: count((u) => u.estado.toLowerCase() == 'activo'),
      inactivos: count((u) => u.estado.toLowerCase() == 'inactivo'),
      administradores: count((u) => u.rol.toLowerCase() == 'administrador'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<AdminUsuariosViewModel>();
    final usuarios = vm.usuarios;
    final usuariosFiltrados = _filteredUsers(usuarios);
    final resumen = _resumen(usuarios, vm.resumen);

    // El boton retroceder nativo pide confirmacion antes de cerrar la app.
    return ExitConfirmGuard(
      child: Scaffold(
        appBar: AppTopBar(
          titleText: 'Panel de administración',
          actions: const [SessionActionsMenu()],
        ),
        body: RefreshIndicator(
          onRefresh: vm.loadUsers,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestión de usuarios',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Control de accesos y cuentas del sistema',
                          style: AppTypography.caption,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: vm.isSaving ? null : () => _openForm(),
                    tooltip: 'Nuevo usuario',
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.onPrimary,
                      disabledBackgroundColor: AppColors.fillDisabled,
                      disabledForegroundColor: AppColors.textDisabled,
                      minimumSize: const Size(48, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.control),
                      ),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      label: 'Cuentas',
                      value: resumen.total,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: 'Activos',
                      value: resumen.activos,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniStat(
                      label: 'Inactivos',
                      value: resumen.inactivos,
                      color: AppColors.warning,
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
                counts: {
                  AdminFilterType.all: resumen.total,
                  AdminFilterType.active: resumen.activos,
                  AdminFilterType.inactive: resumen.inactivos,
                  AdminFilterType.admins: resumen.administradores,
                },
                onSelected: (value) {
                  setState(() => _selectedFilter = value);
                  if (value != AdminFilterType.all) {
                    _ensureAllUsersLoaded();
                  }
                },
              ),
              const SizedBox(height: 12),
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
                      vm.isLoading ? 'Cargando...' : 'Cargar más usuarios',
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
              if (usuarios.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  vm.resumen == null
                      ? 'Mostrando ${usuariosFiltrados.length} de ${usuarios.length} cuentas cargadas'
                      : 'Mostrando ${usuariosFiltrados.length} de ${vm.resumen!.total} cuentas registradas',
                  style: AppTypography.caption,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Tarjeta compacta de conteo de la cabecera del panel.
class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: AppTypography.tabularFigures,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.sectionHeader.copyWith(fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
