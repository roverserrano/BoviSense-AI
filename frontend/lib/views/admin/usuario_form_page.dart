import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../common/bovisense_ui.dart';

class UsuarioFormPage extends StatefulWidget {
  const UsuarioFormPage({super.key, this.usuario});

  final UsuarioModel? usuario;

  @override
  State<UsuarioFormPage> createState() => _UsuarioFormPageState();
}

class _UsuarioFormPageState extends State<UsuarioFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nombreController;
  late final TextEditingController _apellidosController;
  late final TextEditingController _cedulaController;
  late final TextEditingController _correoController;
  late final TextEditingController _telefonoController;

  late String _rol;
  late String _estado;

  bool get _isEditing => widget.usuario != null;

  /// El backend no permite que un administrador se quite su propio acceso.
  bool get _isOwnAccount =>
      _isEditing &&
      widget.usuario!.uid == context.read<AuthViewModel>().currentUser?.uid;

  @override
  void initState() {
    super.initState();

    final usuario = widget.usuario;

    _nombreController = TextEditingController(text: usuario?.nombre ?? '');
    _apellidosController = TextEditingController(
      text: usuario?.apellidos ?? '',
    );
    _cedulaController = TextEditingController(
      text: usuario?.cedulaIdentidad.toString() ?? '',
    );
    _correoController = TextEditingController(text: usuario?.correo ?? '');
    _telefonoController = TextEditingController(
      text: usuario?.telefono.toString() ?? '',
    );

    _rol = usuario?.rol ?? 'usuario';
    _estado = usuario?.estado ?? 'activo';
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _cedulaController.dispose();
    _correoController.dispose();
    _telefonoController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final usuario = UsuarioModel(
      uid: widget.usuario?.uid ?? '',
      nombre: _nombreController.text.trim(),
      apellidos: _apellidosController.text.trim(),
      cedulaIdentidad: int.parse(_cedulaController.text.trim()),
      correo: _correoController.text.trim().toLowerCase(),
      telefono: int.parse(_telefonoController.text.trim()),
      rol: _rol,
      estado: _isEditing ? _estado : 'activo',
      fechaRegistro: widget.usuario?.fechaRegistro,
    );

    final vm = context.read<AdminUsuariosViewModel>();

    final ok = _isEditing
        ? await vm.updateUser(usuario)
        : await vm.createUser(usuario);

    if (!mounted) return;

    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.errorMessage ?? 'No se pudo guardar el usuario.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminUsuariosViewModel>();

    return Scaffold(
      appBar: AppTopBar(
        titleText: _isEditing ? 'Editar usuario' : 'Registrar usuario',
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEditing && widget.usuario != null) ...[
              _identityCard(widget.usuario!),
              const SizedBox(height: 16),
            ],
            const SectionTitle(text: 'Datos personales'),
            BoviCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nombreController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _apellidosController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Apellidos',
                      helperText: 'Apellido paterno y materno',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa los apellidos';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cedulaController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Cédula de identidad',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la cédula';
                      }
                      if (int.tryParse(value.trim()) == null) {
                        return 'La cédula debe ser numérica';
                      }
                      final length = value.trim().length;
                      if (length < 7 || length > 8) {
                        return 'La cédula debe tener 7 u 8 dígitos';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Contacto'),
            BoviCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.alternate_email_rounded),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el correo';
                      }
                      final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                      if (!regex.hasMatch(value.trim())) {
                        return 'Correo inválido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(8),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el teléfono';
                      }
                      if (int.tryParse(value.trim()) == null) {
                        return 'El teléfono debe ser numérico';
                      }
                      if (value.trim().length != 8) {
                        return 'El teléfono debe tener 8 dígitos';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Acceso al sistema'),
            BoviCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _rol,
                    decoration: const InputDecoration(
                      labelText: 'Rol',
                      prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'usuario',
                        child: Text('Usuario'),
                      ),
                      DropdownMenuItem(
                        value: 'administrador',
                        child: Text('Administrador'),
                      ),
                    ],
                    onChanged: _isOwnAccount
                        ? null
                        : (value) {
                            if (value != null) setState(() => _rol = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  if (_isEditing)
                    DropdownButtonFormField<String>(
                      initialValue: _estado,
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.toggle_on_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'activo',
                          child: Text('Activo'),
                        ),
                        DropdownMenuItem(
                          value: 'inactivo',
                          child: Text('Inactivo'),
                        ),
                      ],
                      onChanged: _isOwnAccount
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _estado = value);
                              }
                            },
                    )
                  else
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Estado',
                        prefixIcon: Icon(Icons.toggle_on_outlined),
                      ),
                      child: const Text(
                        'Activo',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  if (_isOwnAccount) ...[
                    const SizedBox(height: 14),
                    const StatusBanner(
                      title: 'Tu propia cuenta',
                      description:
                          'No puedes cambiar tu propio rol ni desactivar tu cuenta.',
                      tone: StatusBannerTone.neutral,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: _isEditing ? 'Actualizar usuario' : 'Registrar usuario',
              isLoading: vm.isSaving,
              onPressed: _save,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _identityCard(UsuarioModel usuario) {
    final isActive = usuario.estado.toLowerCase() == 'activo';
    final initials = _initials(usuario.nombre, usuario.apellidos);

    return BoviCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary,
            child: Text(
              initials,
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
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.25,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(usuario.correo, style: AppTypography.caption),
              ],
            ),
          ),
          StatusChip(
            label: usuario.estado,
            color: isActive ? AppColors.success : AppColors.muted,
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
