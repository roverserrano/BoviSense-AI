import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../viewmodels/auth_view_model.dart';
import '../common/bovisense_logo.dart';
import '../common/bovisense_ui.dart';
import 'recuperar_contrasena_page.dart';

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

    if (ok) {
      // Guarda las credenciales en el gestor de contrasenas del telefono.
      TextInput.finishAutofillContext();
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

  Future<void> _openExternalUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalNonBrowserApplication,
  }) async {
    // En Android, si la app destino (WhatsApp, telefono) no existe, launchUrl
    // puede lanzar PlatformException en lugar de devolver false.
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: mode);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la aplicación solicitada.'),
        ),
      );
    }
  }

  void _showSupportContact() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Contactate con soporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Toca una opción para contactar con soporte.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              _SupportInfoBlock(
                label: 'Teléfono',
                value: AppConfig.supportPhone,
                icon: Icons.phone_outlined,
                tappable: true,
                onTap: () => _openExternalUri(
                  Uri(scheme: 'tel', path: AppConfig.supportPhone),
                  mode: LaunchMode.platformDefault,
                ),
              ),
              const SizedBox(height: 12),
              _SupportInfoBlock(
                label: 'WhatsApp',
                value: AppConfig.supportWhatsapp,
                icon: Icons.chat_rounded,
                tappable: true,
                onTap: () => _openExternalUri(
                  AppConfig.supportWhatsappUri,
                  mode: LaunchMode.externalNonBrowserApplication,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 20,
                  bottom: 18 + bottomInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 38,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _HeroBrand(),
                      const SizedBox(height: 22),
                      _LoginCard(
                        formKey: _formKey,
                        correoController: _correoController,
                        passwordController: _passwordController,
                        passwordFocusNode: _passwordFocusNode,
                        obscureText: _obscureText,
                        isLoading: vm.isLoading,
                        errorMessage: vm.errorMessage,
                        onFieldEdited: vm.clearError,
                        onToggleObscureText: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                        onPasswordRecovery: _openPasswordRecovery,
                        onLogin: _login,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _showSupportContact,
                        icon: const Icon(Icons.support_agent_rounded, size: 18),
                        label: const Text('Necesito ayuda de soporte'),
                      ),
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

class _HeroBrand extends StatelessWidget {
  const _HeroBrand();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 132,
          height: 132,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: const ClipOval(
            child: ColoredBox(
              color: Colors.white,
              child: BoviSenseLogo(size: 120),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('BoviSense', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Text(
            'La inteligencia artificial al servicio del campo',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.formKey,
    required this.correoController,
    required this.passwordController,
    required this.passwordFocusNode,
    required this.obscureText,
    required this.isLoading,
    required this.errorMessage,
    required this.onFieldEdited,
    required this.onToggleObscureText,
    required this.onPasswordRecovery,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController correoController;
  final TextEditingController passwordController;
  final FocusNode passwordFocusNode;
  final bool obscureText;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onFieldEdited;
  final VoidCallback onToggleObscureText;
  final Future<void> Function() onPasswordRecovery;
  final Future<void> Function() onLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: AutofillGroup(
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Bienvenido',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Ingresa tus credenciales para continuar',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                _LoginTextField(
                  controller: correoController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [
                    AutofillHints.username,
                    AutofillHints.email,
                  ],
                  autocorrect: false,
                  enableSuggestions: false,
                  hintText: 'Correo electrónico',
                  prefixIcon: Icons.alternate_email_rounded,
                  onChanged: (_) => onFieldEdited(),
                  onFieldSubmitted: (_) {
                    FocusScope.of(context).requestFocus(passwordFocusNode);
                  },
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
                const SizedBox(height: 14),
                _LoginTextField(
                  controller: passwordController,
                  focusNode: passwordFocusNode,
                  obscureText: obscureText,
                  obscuringCharacter: '•',
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  autocorrect: false,
                  enableSuggestions: false,
                  hintText: 'Contraseña',
                  prefixIcon: Icons.lock_rounded,
                  onChanged: (_) => onFieldEdited(),
                  suffixIcon: IconButton(
                    onPressed: onToggleObscureText,
                    tooltip: obscureText
                        ? 'Mostrar contraseña'
                        : 'Ocultar contraseña',
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                  onFieldSubmitted: (_) {
                    if (!isLoading) {
                      onLogin();
                    }
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Ingresa tu contraseña';
                    }
                    return null;
                  },
                ),
                if (errorMessage != null && !isLoading) ...[
                  const SizedBox(height: 14),
                  StatusBanner(
                    title: errorMessage!,
                    tone: StatusBannerTone.error,
                  ),
                ],
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            onPasswordRecovery();
                          },
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 8),
                PrimaryButton(
                  label: isLoading ? 'Ingresando...' : 'Iniciar sesión',
                  isLoading: isLoading,
                  onPressed: () {
                    onLogin();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginTextField extends StatelessWidget {
  const _LoginTextField({
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.focusNode,
    this.obscureText = false,
    this.obscuringCharacter = '•',
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final FocusNode? focusNode;
  final bool obscureText;
  final String obscuringCharacter;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool autocorrect;
  final bool enableSuggestions;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      obscuringCharacter: obscuringCharacter,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(prefixIcon),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class _SupportInfoBlock extends StatelessWidget {
  const _SupportInfoBlock({
    required this.label,
    required this.value,
    required this.icon,
    required this.tappable,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool tappable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return BoviCard(
      padding: EdgeInsets.zero,
      color: AppColors.surfaceAlt,
      onTap: tappable ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            if (tappable)
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
