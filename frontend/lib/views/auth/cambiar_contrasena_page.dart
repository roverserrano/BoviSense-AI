import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';

class CambiarContrasenaPage extends StatefulWidget {
  const CambiarContrasenaPage({super.key});

  @override
  State<CambiarContrasenaPage> createState() => _CambiarContrasenaPageState();
}

class _CambiarContrasenaPageState extends State<CambiarContrasenaPage> {
  final _formKey = GlobalKey<FormState>();
  final _actualCtrl = TextEditingController();
  final _nuevaCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  bool _obscureActual = true;
  bool _obscureNueva = true;
  bool _obscureConfirmar = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AuthViewModel>().clearError();
    });
  }

  @override
  void dispose() {
    _actualCtrl.dispose();
    _nuevaCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<AuthViewModel>();
    final ok = await vm.changePassword(
      currentPassword: _actualCtrl.text.trim(),
      newPassword: _nuevaCtrl.text.trim(),
    );

    if (!mounted) return;

    if (ok) {
      vm.clearError();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.errorMessage ?? 'No se pudo cambiar la contraseña.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final rule = _PasswordRule.from(_nuevaCtrl.text.trim());

    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _InfoCard(),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _actualCtrl,
                        obscureText: _obscureActual,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Contraseña actual',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureActual = !_obscureActual);
                            },
                            icon: Icon(
                              _obscureActual
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu contraseña actual';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nuevaCtrl,
                        obscureText: _obscureNueva,
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: 'Nueva contraseña',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _obscureNueva = !_obscureNueva);
                            },
                            icon: Icon(
                              _obscureNueva
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          final input = value?.trim() ?? '';
                          if (input.isEmpty) {
                            return 'Ingresa una nueva contraseña';
                          }
                          if (input == _actualCtrl.text.trim()) {
                            return 'La nueva contraseña debe ser distinta';
                          }
                          if (!_PasswordRule.from(input).isStrong) {
                            return 'Usa una contraseña más robusta';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmarCtrl,
                        obscureText: _obscureConfirmar,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (!vm.isChangingPassword) {
                            _submit();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Confirmar nueva contraseña',
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _obscureConfirmar = !_obscureConfirmar,
                              );
                            },
                            icon: Icon(
                              _obscureConfirmar
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Confirma la nueva contraseña';
                          }
                          if (value.trim() != _nuevaCtrl.text.trim()) {
                            return 'Las contraseñas no coinciden';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _SecurityChecklist(rule: rule),
                      if (vm.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          vm.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: vm.isChangingPassword ? null : _submit,
                        child: vm.isChangingPassword
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Guardar nueva contraseña'),
                      ),
                    ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Seguridad de la cuenta',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Para cambiar la contraseña necesitamos confirmar tu contraseña actual. '
              'Evita usar datos personales o contraseñas repetidas.',
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityChecklist extends StatelessWidget {
  const _SecurityChecklist({required this.rule});

  final _PasswordRule rule;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tu nueva contraseña debe tener:',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        _RuleLine(ok: rule.hasMinLength, text: 'Al menos 8 caracteres'),
        _RuleLine(ok: rule.hasUppercase, text: 'Una letra mayúscula'),
        _RuleLine(ok: rule.hasLowercase, text: 'Una letra minúscula'),
        _RuleLine(ok: rule.hasDigit, text: 'Un número'),
      ],
    );
  }
}

class _RuleLine extends StatelessWidget {
  const _RuleLine({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Colors.green.shade700 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: color)),
        ],
      ),
    );
  }
}

class _PasswordRule {
  const _PasswordRule({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasDigit,
  });

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasDigit;

  bool get isStrong => hasMinLength && hasUppercase && hasLowercase && hasDigit;

  factory _PasswordRule.from(String input) {
    final hasUppercase = RegExp(r'[A-Z]').hasMatch(input);
    final hasLowercase = RegExp(r'[a-z]').hasMatch(input);
    final hasDigit = RegExp(r'[0-9]').hasMatch(input);

    return _PasswordRule(
      hasMinLength: input.length >= 8,
      hasUppercase: hasUppercase,
      hasLowercase: hasLowercase,
      hasDigit: hasDigit,
    );
  }
}
