import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import '../common/bovisense_logo.dart';
import 'recuperar_contrasena_page.dart';
import '../ganadero/widgets/ganadero_design_system.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _obscureText = true;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.login(
      email: _correoController.text.trim().toLowerCase(),
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!ok && vm.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
    }
  }

  Future<void> _openPasswordRecovery() async {
    FocusScope.of(context).unfocus();

    final returnedEmail = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => RecuperarContrasenaPage(
          initialEmail: _correoController.text.trim(),
        ),
      ),
    );

    if (!mounted || returnedEmail == null || returnedEmail.isEmpty) return;
    _correoController.text = returnedEmail;
  }

  void _showSupportContact() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 7),
          content: Text(
            'Si necesitas ayuda, puedes solicitarla directamente al administrador.\n'
            'Soporte administrativo\n'
            'Correo: serranorover436@gmail.com\n'
            'Teléfono: 71338567',
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
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 12,
                  bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 24,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECE4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: GanaderoColors.borderSoft,
                            width: 0.5,
                          ),
                        ),
                        child: const Column(
                          children: [
                            BoviSenseLogo(size: 150),
                            SizedBox(height: 10),
                            Text(
                              'BoviSense-AI',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                color: GanaderoColors.textDark,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'La inteligencia artificial al servicio del campo',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.35,
                                color: GanaderoColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: GanaderoColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: GanaderoColors.borderSoft,
                            width: 0.5,
                          ),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            autovalidateMode:
                                AutovalidateMode.onUserInteraction,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SectionTitle(text: 'Acceso seguro'),
                                TextFormField(
                                  controller: _correoController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autofillHints: const [
                                    AutofillHints.username,
                                    AutofillHints.email,
                                  ],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: const InputDecoration(
                                    hintText: 'Correo',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(
                                      context,
                                    ).requestFocus(_passwordFocusNode);
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Ingresa tu correo';
                                    }
                                    final regex = RegExp(
                                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                    );
                                    if (!regex.hasMatch(value.trim())) {
                                      return 'Correo inválido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _passwordController,
                                  focusNode: _passwordFocusNode,
                                  obscureText: _obscureText,
                                  obscuringCharacter: '•',
                                  textInputAction: TextInputAction.done,
                                  autofillHints: const [AutofillHints.password],
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  decoration: InputDecoration(
                                    hintText: 'Contraseña',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscureText = !_obscureText;
                                        });
                                      },
                                      icon: Icon(
                                        _obscureText
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                      ),
                                    ),
                                  ),
                                  onFieldSubmitted: (_) {
                                    if (!vm.isLoading) {
                                      _login();
                                    }
                                  },
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu contraseña';
                                    }
                                    return null;
                                  },
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: vm.isLoading
                                        ? null
                                        : _openPasswordRecovery,
                                    child: const Text(
                                      '¿Olvidaste tu contraseña?',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                PrimaryButton(
                                  label: vm.isLoading
                                      ? 'Entrando...'
                                      : 'Entrar',
                                  onPressed: vm.isLoading ? null : _login,
                                  isLoading: vm.isLoading,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton.icon(
                        onPressed: _showSupportContact,
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: const Text('Necesito ayuda de soporte'),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
