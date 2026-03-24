import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../viewmodels/ganadero_view_model.dart';
import 'conteo_detalle_page.dart';

class HistorialConteosPage extends StatefulWidget {
  const HistorialConteosPage({super.key});

  @override
  State<HistorialConteosPage> createState() => _HistorialConteosPageState();
}

class _HistorialConteosPageState extends State<HistorialConteosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GanaderoViewModel>().loadHistorial();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de conteos')),
      body: RefreshIndicator(
        onRefresh: vm.loadHistorial,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (vm.errorMessage != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    vm.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            if (vm.isLoadingHistorial && vm.historial.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (vm.historial.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: const [
                      Icon(
                        Icons.history_toggle_off_rounded,
                        size: 56,
                        color: Color(0xFF2E7D32),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no hay conteos registrados.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...vm.historial.map(
                (conteo) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF2E7D32),
                        child: Icon(
                          Icons.analytics_outlined,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(formatDateTime(conteo.fechaHoraInicio)),
                      subtitle: Text(
                        'Detectados: ${conteo.cantidadDetectada} | Esperados: ${conteo.cantidadEsperada}',
                      ),
                      trailing: Text(
                        formatSignedInt(conteo.diferencia),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: conteo.diferencia == 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                ConteoDetallePage(conteoId: conteo.id),
                          ),
                        );
                      },
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
