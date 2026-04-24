import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/usuario_model.dart';
import '../../viewmodels/admin_usuarios_view_model.dart';
import 'widgets/admin_tokens.dart';
import 'widgets/section_label.dart';

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
      backgroundColor: AdminPalette.pageBg,
      appBar: AppBar(
        backgroundColor: AdminPalette.appBar,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(_isEditing ? 'Editar usuario' : 'Registrar usuario'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isEditing && widget.usuario != null) ...[
              _identityCard(widget.usuario!),
              const SizedBox(height: 14),
            ],
            if (!_isEditing) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7E8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminPalette.border, width: 0.5),
                ),
                child: const Text(
                  'La contraseña inicial se genera automáticamente a partir del nombre y apellido. '
                  'Ejemplo: Juan Pérez -> jperez. Luego se envía por correo electrónico.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF3B6D11),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
            const SectionLabel(text: 'Datos personales'),
            _sectionCard(
              children: [
                _fieldRow(
                  label: 'Nombre',
                  child: TextFormField(
                    controller: _nombreController,
                    decoration: _fieldDecoration(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre';
                      }
                      return null;
                    },
                  ),
                ),
                _thinDivider(),
                _fieldRow(
                  label: 'Apellidos',
                  child: TextFormField(
                    controller: _apellidosController,
                    decoration: _fieldDecoration(),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa los apellidos';
                      }
                      return null;
                    },
                  ),
                ),
                _thinDivider(),
                _fieldRow(
                  label: 'Cédula de identidad',
                  child: TextFormField(
                    controller: _cedulaController,
                    keyboardType: TextInputType.number,
                    decoration: _fieldDecoration(),
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
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionLabel(text: 'Contacto'),
            _sectionCard(
              children: [
                _fieldRow(
                  label: 'Correo electrónico',
                  child: TextFormField(
                    controller: _correoController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _fieldDecoration(),
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
                ),
                _thinDivider(),
                _fieldRow(
                  label: 'Teléfono',
                  child: TextFormField(
                    controller: _telefonoController,
                    keyboardType: TextInputType.phone,
                    decoration: _fieldDecoration(),
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
                ),
              ],
            ),
            const SizedBox(height: 14),
            const SectionLabel(text: 'Acceso al sistema'),
            _sectionCard(
              children: [
                _dropdownRow(
                  label: 'Rol',
                  value: _rol,
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
                _thinDivider(),
                _dropdownRow(
                  label: 'Estado',
                  value: _estado,
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
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: vm.isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                elevation: 0,
                backgroundColor: AdminPalette.primary,
                foregroundColor: AdminPalette.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: vm.isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Actualizar usuario' : 'Registrar usuario',
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _identityCard(UsuarioModel usuario) {
    final isActive = usuario.estado.toLowerCase() == 'activo';
    final initials = _initials(usuario.nombre, usuario.apellidos);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AdminPalette.primary,
            child: Text(
              initials,
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: isActive ? AdminPalette.activeBg : AdminPalette.inactiveBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              usuario.estado,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? AdminPalette.activeText
                    : AdminPalette.inactiveText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AdminPalette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AdminPalette.border, width: 0.5),
      ),
      child: Column(children: children),
    );
  }

  Widget _fieldRow({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AdminPalette.muted),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  Widget _dropdownRow({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AdminPalette.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 170,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                initialValue: value,
                items: items,
                onChanged: onChanged,
                decoration: const InputDecoration(
                  isDense: true,
                  filled: false,
                  border: UnderlineInputBorder(borderSide: BorderSide.none),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                style: const TextStyle(
                  fontSize: 13,
                  color: AdminPalette.textPrimary,
                ),
                dropdownColor: AdminPalette.card,
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration() {
    return const InputDecoration(
      isDense: true,
      filled: false,
      border: UnderlineInputBorder(borderSide: BorderSide.none),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide.none),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide.none),
      errorBorder: UnderlineInputBorder(borderSide: BorderSide.none),
      focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide.none),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _thinDivider() {
    return Container(height: 0.5, color: const Color(0xFFE8E2D4));
  }

  String _initials(String name, String lastName) {
    final first = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '';
    final second = lastName.trim().isNotEmpty
        ? lastName.trim()[0].toUpperCase()
        : (name.trim().length > 1 ? name.trim()[1].toUpperCase() : 'U');
    return '$first$second';
  }
}
