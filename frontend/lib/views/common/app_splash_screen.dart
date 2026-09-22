import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/auth_view_model.dart';
import 'bovisense_logo.dart';

/// Muestra la presentacion mientras la sesion se inicializa.
///
/// Antes esperaba siempre 1,7 s aunque la aplicacion estuviera lista: un
/// retraso artificial en cada arranque. Ahora sale en cuanto la inicializacion
/// termina, con un minimo para que la marca se vea y un maximo de seguridad.
class AppSplashScreen extends StatefulWidget {
  const AppSplashScreen({
    super.key,
    required this.child,
    this.minimumDuration = const Duration(milliseconds: 1200),
    this.maximumDuration = const Duration(seconds: 4),
  });

  final Widget child;
  final Duration minimumDuration;
  final Duration maximumDuration;

  /// Reglas de salida de la presentacion:
  /// - se respeta un minimo para que la marca se vea;
  /// - se sale en cuanto la sesion termina de inicializarse;
  /// - y nunca se pasa del maximo, aunque la inicializacion se quede colgada.
  @visibleForTesting
  static bool isReady({
    required bool minimumElapsed,
    required bool maximumElapsed,
    required bool initializing,
  }) {
    if (maximumElapsed) return true;
    return minimumElapsed && !initializing;
  }

  @override
  State<AppSplashScreen> createState() => _AppSplashScreenState();
}

class _AppSplashScreenState extends State<AppSplashScreen> {
  Timer? _minimumTimer;
  Timer? _maximumTimer;
  bool _minimumElapsed = false;
  bool _maximumElapsed = false;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(widget.minimumDuration, () {
      if (mounted) setState(() => _minimumElapsed = true);
    });
    // Red de seguridad: nunca dejar la aplicacion atrapada en la presentacion.
    _maximumTimer = Timer(widget.maximumDuration, () {
      if (mounted) setState(() => _maximumElapsed = true);
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _maximumTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initializing = context.select<AuthViewModel, bool>(
      (vm) => vm.isInitializing,
    );
    final ready = AppSplashScreen.isReady(
      minimumElapsed: _minimumElapsed,
      maximumElapsed: _maximumElapsed,
      initializing: initializing,
    );
    return ready ? widget.child : const AppSplashView();
  }
}

class AppSplashView extends StatelessWidget {
  const AppSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F1EB),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              BoviSenseLogo(size: 160),
              SizedBox(height: 18),
              Text(
                'BoviSense',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2D4228),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Inteligencia aplicada al campo',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF5A7254),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A6741)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
