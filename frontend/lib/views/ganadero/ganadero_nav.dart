import 'package:flutter/material.dart';

import 'configuracion_sistema_page.dart';
import 'estado_dispositivo_page.dart';
import 'ganadero_dashboard_page.dart';
import 'historial_conteos_page.dart';

void goToGanaderoTab(BuildContext context, int index) {
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
