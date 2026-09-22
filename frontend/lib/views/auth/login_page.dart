import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
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
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Text('Contactate con soporte'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toca una opción para contactar con soporte.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: GanaderoColors.textSecondary,
                ),
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
        backgroundColor: AppTheme.bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF8F6F1), Color(0xFFF2EFE7), Color(0xFFF8F6F1)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    SingleChildScrollView(
                      padding: EdgeInsets.only(
                        left: 18,
                        right: 18,
                        top: 10,
                        bottom: 18 + bottomInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 28,
                        ),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _HeroBrand(),
                            const SizedBox(height: 20),
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
                            const SizedBox(height: 12),
                            TextButton.icon(
                              onPressed: _showSupportContact,
                              icon: const Icon(
                                Icons.support_agent_rounded,
                                size: 18,
                              ),
                              label: const Text('Necesito ayuda de soporte'),
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 148,
          height: 148,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6F1),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: GanaderoColors.borderSoft, width: 1),
          ),
          child: const ClipOval(
            child: ColoredBox(
              color: Colors.white,
              child: BoviSenseLogo(
                size: 134,
                fit: BoxFit.cover,
                alignment: Alignment(0, -0.82),
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'BoviSense',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: GanaderoColors.textDark,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 8),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: const Text(
            'La inteligencia artificial al servicio del campo',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: GanaderoColors.textSecondary,
              letterSpacing: 0.15,
            ),
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
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFDDE7D6), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        child: AutofillGroup(
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Bienvenido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    color: GanaderoColors.textDark,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Ingresa tus credenciales para continuar',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.45,
                    color: GanaderoColors.textSecondary,
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
                    icon: Icon(
                      obscureText
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    color: GanaderoColors.muted,
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
                  _LoginErrorBox(message: errorMessage!),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            onPasswordRecovery();
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: GanaderoColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('¿Olvidaste tu contraseña?'),
                  ),
                ),
                const SizedBox(height: 10),
                _LoginActionButton(
                  label: 'Iniciar sesión',
                  isLoading: isLoading,
                  onPressed: isLoading
                      ? null
                      : () {
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
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: GanaderoColors.textDark,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Color(0xFF8D9B88),
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6F1),
        prefixIcon: Container(
          margin: const EdgeInsets.all(10),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0DE),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(prefixIcon, color: GanaderoColors.primary, size: 20),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 62),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFD6E1D0), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFD6E1D0), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(
            color: GanaderoColors.primary,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC6655D), width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: const BorderSide(color: Color(0xFFC6655D), width: 1.4),
        ),
      ),
    );
  }
}

class _LoginActionButton extends StatelessWidget {
  const _LoginActionButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: GanaderoColors.primary.withValues(
              alpha: isLoading ? 0.18 : 0.28,
            ),
            blurRadius: isLoading ? 12 : 18,
            offset: Offset(0, isLoading ? 5 : 8),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: GanaderoColors.primary,
          disabledBackgroundColor: GanaderoColors.primary,
          foregroundColor: GanaderoColors.buttonText,
          disabledForegroundColor: GanaderoColors.buttonText,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        onPressed: isLoading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.96, end: 1).animate(animation),
                child: child,
              ),
            );
          },
          child: isLoading
              ? const Row(
                  key: ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: GanaderoColors.buttonText,
                        backgroundColor: Color(0x334A6741),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Ingresando...',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: GanaderoColors.buttonText,
                      ),
                    ),
                  ],
                )
              : Row(
                  key: const ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
        ),
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
    final content = Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE4F0DE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: GanaderoColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GanaderoColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GanaderoColors.textDark,
                  ),
                ),
              ],
            ),
          ),
          if (tappable)
            const Icon(
              Icons.chevron_right_rounded,
              color: GanaderoColors.muted,
            ),
        ],
      ),
    );

    return Material(
      color: GanaderoColors.surfaceAlt,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: tappable ? onTap : null,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: GanaderoColors.borderSoft, width: 0.8),
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Error de inicio de sesion dentro de la tarjeta.
///
/// Antes solo se avisaba con un SnackBar, que desaparece y puede quedar tapado
/// por el teclado; aqui el mensaje queda visible hasta que el usuario corrige.
class _LoginErrorBox extends StatelessWidget {
  const _LoginErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3B4AE), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFF9C3B31),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF7A2820),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
