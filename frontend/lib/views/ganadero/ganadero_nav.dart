import 'package:flutter/material.dart';

import '../common/exit_confirm.dart';
import 'configuracion_sistema_page.dart';
import 'estado_dispositivo_page.dart';
import 'ganadero_dashboard_page.dart';
import 'historial_conteos_page.dart';

void goToGanaderoTab(BuildContext context, int index) {
  final scope = _GanaderoTabsScope.maybeOf(context);
  if (scope != null) {
    scope.goToTab(index);
    return;
  }

  final Widget target;
  switch (index) {
    case 0:
      target = const GanaderoDashboardPage();
      break;
    case 1:
      target = const ConfiguracionSistemaPage();
      break;
    case 2:
      target = const EstadoDispositivoPage();
      break;
    case 3:
      target = const HistorialConteosPage();
      break;
    default:
      target = const GanaderoDashboardPage();
  }

  Navigator.of(
    context,
  ).pushReplacement(MaterialPageRoute(builder: (_) => target));
}

class GanaderoShellPage extends StatefulWidget {
  const GanaderoShellPage({super.key});

  @override
  State<GanaderoShellPage> createState() => _GanaderoShellPageState();
}

class _GanaderoShellPageState extends State<GanaderoShellPage> {
  static const int _homeTab = 0;
  int _currentIndex = _homeTab;

  void _goToTab(int index) {
    if (index < 0 || index > 3 || index == _currentIndex) return;
    setState(() => _currentIndex = index);
  }

  /// El retroceso vuelve a la pestana inicial; en la pestana inicial deja que
  /// [ExitConfirmGuard] pregunte si se cierra la aplicacion.
  Future<bool> _handleBackPressed() async {
    if (_currentIndex != _homeTab) {
      setState(() => _currentIndex = _homeTab);
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _GanaderoTabsScope(
      currentIndex: _currentIndex,
      goToTab: _goToTab,
      child: ExitConfirmGuard(
        onBack: _handleBackPressed,
        child: IndexedStack(
          index: _currentIndex,
          children: const [
            GanaderoDashboardPage(),
            ConfiguracionSistemaPage(),
            EstadoDispositivoPage(),
            HistorialConteosPage(),
          ],
        ),
      ),
    );
  }
}

class _GanaderoTabsScope extends InheritedWidget {
  const _GanaderoTabsScope({
    required this.currentIndex,
    required this.goToTab,
    required super.child,
  });

  final int currentIndex;
  final ValueChanged<int> goToTab;

  static _GanaderoTabsScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_GanaderoTabsScope>();
  }

  @override
  bool updateShouldNotify(_GanaderoTabsScope oldWidget) {
    return currentIndex != oldWidget.currentIndex;
  }
}
