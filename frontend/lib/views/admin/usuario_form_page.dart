import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';

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
      estado: _estado,
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar usuario' : 'Registrar usuario'),
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isEditing)
                  Card(
                    color: const Color(0xFFE8F5E9),
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'La contraseña inicial se genera automáticamente a partir del nombre y apellido.\nEjemplo: Juan Pérez → jperez.\nLuego se envía por correo electrónico.',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _apellidosController,
                  decoration: const InputDecoration(
                    labelText: 'Apellidos',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa los apellidos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _cedulaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cédula de identidad',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Ingresa la cédula';
                    }
                    if (int.tryParse(value.trim()) == null) {
                      return 'La cédula debe ser numérica';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _correoController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Correo',
                    prefixIcon: Icon(Icons.email_outlined),
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _telefonoController,
                  keyboardType: TextInputType.phone,
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
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _rol,
                  decoration: const InputDecoration(
                    labelText: 'Rol',
                    prefixIcon: Icon(Icons.manage_accounts_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'usuario', child: Text('Usuario')),
                    DropdownMenuItem(
                      value: 'administrador',
                      child: Text('Administrador'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _rol = value);
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _estado,
                  decoration: const InputDecoration(
                    labelText: 'Estado',
                    prefixIcon: Icon(Icons.toggle_on_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(
                      value: 'inactivo',
                      child: Text('Inactivo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _estado = value);
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: vm.isSaving ? null : _save,
                  icon: vm.isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isEditing
                              ? Icons.save_rounded
                              : Icons.person_add_alt_1_rounded,
                        ),
                  label: Text(
                    vm.isSaving
                        ? 'Guardando...'
                        : (_isEditing
                              ? 'Actualizar usuario'
                              : 'Registrar usuario'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
