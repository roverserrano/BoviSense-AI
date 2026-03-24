import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../viewmodels/ganadero_view_model.dart';

class EstadoDispositivoPage extends StatefulWidget {
  const EstadoDispositivoPage({super.key});

  @override
  State<EstadoDispositivoPage> createState() => _EstadoDispositivoPageState();
}

class _EstadoDispositivoPageState extends State<EstadoDispositivoPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GanaderoViewModel>().loadDashboard();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();
    final dispositivo = vm.dispositivo;

    return Scaffold(
      appBar: AppBar(title: const Text('Estado del prototipo')),
      body: ListView(
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
          if (vm.isLoadingDashboard && dispositivo == null)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (dispositivo == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(
                      Icons.memory_rounded,
                      size: 56,
                      color: Color(0xFF2E7D32),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'No hay información del prototipo.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _DeviceRow(
                      label: 'Nombre',
                      value: dispositivo.nombreDispositivo,
                    ),
                    _DeviceRow(
                      label: 'Tipo',
                      value: dispositivo.tipoDispositivo,
                    ),
                    _DeviceRow(
                      label: 'Conexión',
                      value: dispositivo.estadoConexion,
                    ),
                    _DeviceRow(
                      label: 'Estado operativo',
                      value: dispositivo.estadoOperativo,
                    ),
                    _DeviceRow(
                      label: 'Batería',
                      value:
                          '${(dispositivo.nivelBateria * 100).toStringAsFixed(0)}%',
                    ),
                    _DeviceRow(label: 'Modo', value: dispositivo.modoOperacion),
                    _DeviceRow(
                      label: 'Versión modelo',
                      value: dispositivo.versionModelo,
                    ),
                    _DeviceRow(
                      label: 'Última sincronización',
                      value: formatDateTime(dispositivo.ultimaSincronizacion),
                    ),
                    _DeviceRow(
                      label: 'Coordenadas GPS',
                      value: dispositivo.coordenadasGps.isEmpty
                          ? 'No disponible'
                          : dispositivo.coordenadasGps,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: const Color(0xFFE8F5E9),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Por ahora el prototipo está en modo simulación desde backend. '
                  'Cuando integremos LoRa + ESP32, esta pantalla seguirá funcionando, '
                  'pero el estado vendrá desde el dispositivo real.',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
