import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Evita que se apilen varios dialogos si el usuario insiste con el boton
/// retroceder.
bool _isAskingExit = false;

/// Pregunta si se quiere cerrar la aplicacion con el boton retroceder nativo.
///
/// Devuelve `true` solo si el usuario confirma.
Future<bool> confirmExitApp(BuildContext context) async {
  if (_isAskingExit) return false;
  _isAskingExit = true;
  try {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Salir de BoviSense?'),
        content: const Text('¿Quieres cerrar la aplicación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    return shouldExit == true;
  } finally {
    _isAskingExit = false;
  }
}

/// Cierra la aplicacion si el usuario confirma.
Future<void> confirmAndExitApp(BuildContext context) async {
  if (await confirmExitApp(context)) SystemNavigator.pop();
}

/// Envuelve la pantalla raiz de un rol para pedir confirmacion antes de salir.
///
/// [onBack] permite manejar primero el retroceso dentro de la pantalla (por
/// ejemplo, volver a la pestana inicial) y debe devolver `true` si ya lo hizo.
class ExitConfirmGuard extends StatelessWidget {
  const ExitConfirmGuard({super.key, required this.child, this.onBack});

  final Widget child;
  final Future<bool> Function()? onBack;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (onBack != null && await onBack!()) return;
        if (!context.mounted) return;
        await confirmAndExitApp(context);
      },
      child: child,
    );
  }
}
