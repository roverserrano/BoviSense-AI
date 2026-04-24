import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../ganadero/widgets/ganadero_design_system.dart';

class RecuperarContrasenaPage extends StatefulWidget {
  const RecuperarContrasenaPage({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<RecuperarContrasenaPage> createState() =>
      _RecuperarContrasenaPageState();
}

class _RecuperarContrasenaPageState extends State<RecuperarContrasenaPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _correoController;

  @override
  void initState() {
    super.initState();
    _correoController = TextEditingController(
      text: widget.initialEmail?.trim().toLowerCase() ?? '',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    _correoController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.requestPasswordReset(
      email: _correoController.text.trim().toLowerCase(),
    );

    if (!mounted) return;

    if (ok) {
      vm.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Si el correo está registrado, recibirás un enlace para restablecer tu contraseña.',
          ),
        ),
      );
      Navigator.of(context).pop(_correoController.text.trim().toLowerCase());
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vm.errorMessage ??
              'No se pudo procesar la solicitud. Intenta nuevamente.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Recuperar contraseña')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GanaderoColors.successBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: GanaderoColors.borderSoft,
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'Ingresa tu correo corporativo para enviar un enlace de restablecimiento. '
                  'Por seguridad, siempre mostraremos la misma confirmación.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: GanaderoColors.successText,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: GanaderoColors.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: GanaderoColors.borderSoft,
                    width: 0.5,
                  ),
                ),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle(text: 'Recuperación de acceso'),
                      TextFormField(
                        controller: _correoController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [
                          AutofillHints.username,
                          AutofillHints.email,
                        ],
                        autocorrect: false,
                        enableSuggestions: false,
                        onFieldSubmitted: (_) {
                          if (!vm.isSendingPasswordReset) {
                            _submit();
                          }
                        },
                        decoration: const InputDecoration(
                          hintText: 'Correo',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                          if (!regex.hasMatch(value.trim())) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: vm.isSendingPasswordReset
                            ? 'Enviando enlace...'
                            : 'Enviar enlace de recuperación',
                        onPressed: vm.isSendingPasswordReset ? null : _submit,
                        isLoading: vm.isSendingPasswordReset,
                      ),
                    ],
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
