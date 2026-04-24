import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
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

  bool _obscureText = true;

  @override
  void dispose() {
    _correoController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.login(
      email: _correoController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!ok && vm.errorMessage != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(vm.errorMessage!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: const [
                        _LoginMark(),
                        SizedBox(height: 12),
                        Text(
                          'BoviSense-AI',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: GanaderoColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: GanaderoColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: GanaderoColors.borderSoft,
                        width: 0.5,
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SectionTitle(text: 'Acceso'),
                          TextFormField(
                            controller: _correoController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'Correo',
                            ),
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
                            obscureText: _obscureText,
                            decoration: InputDecoration(
                              hintText: 'Contraseña',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() => _obscureText = !_obscureText);
                                },
                                icon: Icon(
                                  _obscureText
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa tu contraseña';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),
                          PrimaryButton(
                            label: vm.isLoading ? 'Entrando...' : 'Entrar',
                            onPressed: vm.isLoading ? null : _login,
                            isLoading: vm.isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Soporte: contacta al administrador.'),
                        ),
                      );
                    },
                    child: const Text('Necesito ayuda de soporte'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginMark extends StatelessWidget {
  const _LoginMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: GanaderoColors.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.agriculture_rounded,
        color: GanaderoColors.buttonText,
        size: 30,
      ),
    );
  }
}
