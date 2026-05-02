import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _openExternalUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalNonBrowserApplication,
  }) async {
    final ok = await launchUrl(uri, mode: mode);
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
        const supportPhone = '71338567';
        const supportWhatsapp = '+59171338567';

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
                value: supportPhone,
                icon: Icons.phone_outlined,
                tappable: true,
                onTap: () => _openExternalUri(
                  Uri(scheme: 'tel', path: supportPhone),
                  mode: LaunchMode.platformDefault,
                ),
              ),
              const SizedBox(height: 12),
              _SupportInfoBlock(
                label: 'WhatsApp',
                value: supportWhatsapp,
                icon: Icons.chat_rounded,
                tappable: true,
                onTap: () => _openExternalUri(
                  Uri.parse(
                    'whatsapp://send?phone=59171338567&text=Hola%2C%20necesito%20ayuda%20con%20BoviSense%20AI.',
                  ),
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
          width: 142,
          height: 142,
          decoration: BoxDecoration(
            color: GanaderoColors.surfaceAlt,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: GanaderoColors.borderSoft, width: 1),
          ),
          child: const ClipOval(
            child: SizedBox(
              width: 142,
              height: 142,
              child: BoviSenseLogo(
                size: 142,
                fit: BoxFit.cover,
                alignment: Alignment(0, -0.92),
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
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -20,
            child: _GlowOrb(size: 92, color: const Color(0x184A6741)),
          ),
          Padding(
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
                      label: isLoading ? 'espere por favor' : 'Iniciar sesión',
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
        ],
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
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: GanaderoColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
          duration: const Duration(milliseconds: 180),
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
                        color: GanaderoColors.primary,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'espere por favor',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
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

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
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
