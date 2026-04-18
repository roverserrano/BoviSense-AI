import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/services/esp8266_bridge_service.dart';
import '../../data/services/esp8266_discovery_service.dart';
import '../../viewmodels/ganadero_view_model.dart';

class EstadoDispositivoPage extends StatefulWidget {
  const EstadoDispositivoPage({super.key});

  @override
  State<EstadoDispositivoPage> createState() => _EstadoDispositivoPageState();
}

class _EstadoDispositivoPageState extends State<EstadoDispositivoPage> {
  Esp8266BridgeStatus? _esp8266Status;
  bool _isTestingEsp8266 = false;
  String? _esp8266Error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GanaderoViewModel>().loadDashboard();
    });
  }

  Future<void> _testEsp8266Connection(Esp8266DiscoveryService discovery) async {
    var baseUrl = discovery.baseUrl;
    if (baseUrl == null) {
      await discovery.requestNow();
      baseUrl = discovery.baseUrl;
    }

    if (baseUrl == null) {
      setState(() {
        _esp8266Status = null;
        _esp8266Error =
            'Dispositivo no descubierto. Mantén activo el hotspot HONOR X8b y espera el anuncio UDP del ESP8266.';
      });
      return;
    }

    setState(() {
      _isTestingEsp8266 = true;
      _esp8266Error = null;
    });

    final esp8266Service = Esp8266BridgeService(baseUrl: baseUrl);
    try {
      await esp8266Service.ping();
      final status = await esp8266Service.status();
      if (!mounted) {
        return;
      }
      setState(() {
        _esp8266Status = status;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _esp8266Status = null;
        _esp8266Error =
            'No se pudo contactar el ESP8266 en $baseUrl. Verifica que el hotspot HONOR X8b esté activo y que el ESP8266 siga anunciándose.';
      });
    } finally {
      esp8266Service.close();
      if (mounted) {
        setState(() {
          _isTestingEsp8266 = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();
    final discovery = context.watch<Esp8266DiscoveryService>();
    final dispositivo = vm.dispositivo;

    return Scaffold(
      appBar: AppBar(title: const Text('Estado del prototipo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Conexión directa ESP8266',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'El ESP8266 se descubre automáticamente por UDP dentro del hotspot HONOR X8b.',
                  ),
                  const SizedBox(height: 12),
                  _DiscoveryStatus(discovery: discovery),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isTestingEsp8266
                        ? null
                        : () => _testEsp8266Connection(discovery),
                    icon: _isTestingEsp8266
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.wifi_tethering_rounded),
                    label: Text(
                      _isTestingEsp8266
                          ? 'Probando conexión'
                          : discovery.isAvailable
                          ? 'Probar conexión ESP8266'
                          : 'Buscar y probar ESP8266',
                    ),
                  ),
                  if (_esp8266Error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _esp8266Error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  if (_esp8266Status != null) ...[
                    const SizedBox(height: 12),
                    _DeviceRow(
                      label: 'Dispositivo',
                      value: _esp8266Status!.device,
                    ),
                    _DeviceRow(label: 'Modo', value: _esp8266Status!.mode),
                    _DeviceRow(label: 'SSID', value: _esp8266Status!.ssid),
                    _DeviceRow(label: 'IP', value: _esp8266Status!.ip),
                    _DeviceRow(
                      label: 'Wi-Fi',
                      value: _esp8266Status!.wifiConnected
                          ? 'Conectado'
                          : 'Desconectado',
                    ),
                    _DeviceRow(
                      label: 'Señal Wi-Fi',
                      value: '${_esp8266Status!.wifiRssi} dBm',
                    ),
                    _DeviceRow(
                      label: 'LoRa',
                      value: _esp8266Status!.loraReady
                          ? 'Activo'
                          : 'No iniciado',
                    ),
                    _DeviceRow(
                      label: 'Direcciones',
                      value:
                          '${_esp8266Status!.localAddress} -> ${_esp8266Status!.remoteAddress}',
                    ),
                    _DeviceRow(
                      label: 'TX/RX',
                      value: '${_esp8266Status!.tx}/${_esp8266Status!.rx}',
                    ),
                    _DeviceRow(
                      label: 'Último LoRa RX',
                      value: _esp8266Status!.lastRxMessage.isEmpty
                          ? 'Sin mensajes'
                          : _esp8266Status!.lastRxMessage,
                    ),
                    _DeviceRow(
                      label: 'Señal RX',
                      value:
                          '${_esp8266Status!.lastRxSender} | RSSI ${_esp8266Status!.lastRxRssi} dBm | SNR ${_esp8266Status!.lastRxSnr.toStringAsFixed(2)}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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

class _DiscoveryStatus extends StatelessWidget {
  const _DiscoveryStatus({required this.discovery});

  final Esp8266DiscoveryService discovery;

  @override
  Widget build(BuildContext context) {
    final device = discovery.device;
    final Color color;
    final IconData icon;
    final String title;
    final String detail;

    switch (discovery.state) {
      case Esp8266DiscoveryState.notStarted:
        color = Colors.grey;
        icon = Icons.search_rounded;
        title = 'Descubrimiento no iniciado';
        detail = 'Esperando iniciar escucha UDP.';
        break;
      case Esp8266DiscoveryState.listening:
        color = Colors.orange;
        icon = Icons.radar_rounded;
        title = 'Buscando ESP8266';
        detail = 'Escuchando anuncios UDP en el puerto 4210.';
        break;
      case Esp8266DiscoveryState.found:
        color = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        title = 'Dispositivo encontrado';
        detail = device == null
            ? 'ESP8266 disponible.'
            : '${device.baseUrl} | ID ${device.id}';
        break;
      case Esp8266DiscoveryState.offline:
        color = Colors.red;
        icon = Icons.wifi_off_rounded;
        title = 'Dispositivo no disponible';
        detail = device == null
            ? 'No se reciben anuncios recientes.'
            : 'Último anuncio desde ${device.baseUrl}.';
        break;
      case Esp8266DiscoveryState.error:
        color = Colors.red;
        icon = Icons.error_rounded;
        title = 'Error de descubrimiento';
        detail = discovery.errorMessage ?? 'No se pudo escuchar UDP.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(detail),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
