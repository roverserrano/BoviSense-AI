import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/services/esp32_ble_bridge_service.dart';
import '../../viewmodels/ganadero_view_model.dart';

class EstadoDispositivoPage extends StatefulWidget {
  const EstadoDispositivoPage({super.key});

  @override
  State<EstadoDispositivoPage> createState() => _EstadoDispositivoPageState();
}

class _EstadoDispositivoPageState extends State<EstadoDispositivoPage> {
  final TextEditingController _commandController = TextEditingController(
    text: 'PING',
  );
  bool _isSendingCommand = false;
  bool _isCheckingPrototypeStatus = false;
  bool _countOrderSent = false;
  bool _prototypeStatusSent = false;
  String? _countActionLabel;
  String? _bridgeError;

  bool get _isCountCommandInFlight => _countActionLabel != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GanaderoViewModel>().loadDashboard();
    });
  }

  @override
  void dispose() {
    _commandController.dispose();
    super.dispose();
  }

  Future<void> _connectBridge(Esp32BleBridgeService bridge) async {
    setState(() {
      _bridgeError = null;
    });

    try {
      await bridge.scanAndConnect();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bridgeError = 'No se pudo conectar por BLE: $e';
      });
    }
  }

  Future<bool> _sendCommand(Esp32BleBridgeService bridge) async {
    final command = _commandController.text.trim();
    if (command.isEmpty) {
      setState(() {
        _bridgeError = 'Escribe un comando antes de enviar.';
      });
      return false;
    }

    setState(() {
      _isSendingCommand = true;
      _bridgeError = null;
    });

    try {
      await bridge.sendCommand(command);
    } catch (e) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _bridgeError = e.toString();
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCommand = false;
        });
      }
    }

    return true;
  }

  Future<void> _sendPrototypeStatus(Esp32BleBridgeService bridge) async {
    final requestedAt = DateTime.now();

    setState(() {
      _isCheckingPrototypeStatus = true;
      _prototypeStatusSent = false;
      _bridgeError = null;
    });

    try {
      _commandController.text = 'ESTADO';
      final sent = await _sendCommand(bridge);
      if (!mounted || !sent) {
        return;
      }

      final confirmed = await _waitForJetsonStatus(bridge, requestedAt);
      if (!mounted) {
        return;
      }

      if (confirmed) {
        setState(() {
          _prototypeStatusSent = true;
        });
      } else {
        setState(() {
          _bridgeError =
              'No llegó la respuesta del equipo. Acerca los módulos LoRa y vuelve a intentar.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingPrototypeStatus = false;
        });
      }
    }
  }

  Future<void> _startCounting(Esp32BleBridgeService bridge) async {
    await _sendCountCommand(
      bridge,
      command: 'INICIARCONTEO',
      inProgressLabel: 'Iniciando conteo',
      markStartSent: true,
    );
  }

  Future<void> _sendCountCommand(
    Esp32BleBridgeService bridge, {
    required String command,
    required String inProgressLabel,
    bool markStartSent = false,
  }) async {
    setState(() {
      _countActionLabel = inProgressLabel;
      if (markStartSent) {
        _countOrderSent = false;
      }
      _bridgeError = null;
    });

    try {
      _commandController.text = command;
      final sent = await _sendCommand(bridge);
      if (mounted && sent && markStartSent) {
        setState(() {
          _countOrderSent = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _countActionLabel = null;
        });
      }
    }
  }

  Future<bool> _waitForJetsonStatus(
    Esp32BleBridgeService bridge,
    DateTime requestedAt,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (DateTime.now().isBefore(deadline)) {
      final status = bridge.latestJetsonStatus;
      if (status != null && status.receivedAt.isAfter(requestedAt)) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();
    final bridge = context.watch<Esp32BleBridgeService>();
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
                    'Revisión del equipo',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Conecta el teléfono al prototipo y revisa si la computadora de campo respondió correctamente.',
                  ),
                  const SizedBox(height: 12),
                  _BleBridgeStatus(bridge: bridge),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: bridge.isBusy
                        ? null
                        : bridge.isConnected
                        ? null
                        : () => _connectBridge(bridge),
                    icon: bridge.isBusy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            bridge.isConnected
                                ? Icons.check_circle_rounded
                                : Icons.bluetooth_searching_rounded,
                          ),
                    label: Text(
                      bridge.isBusy
                          ? 'Buscando equipo cercano'
                          : bridge.isConnected
                          ? 'Teléfono conectado al equipo'
                          : 'Conectar teléfono al equipo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: bridge.isConnected ? bridge.disconnect : null,
                    icon: const Icon(Icons.bluetooth_disabled_rounded),
                    label: const Text('Desconectar'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        !bridge.isConnected ||
                            _isSendingCommand ||
                            _isCheckingPrototypeStatus ||
                            _isCountCommandInFlight
                        ? null
                        : () => _sendPrototypeStatus(bridge),
                    icon: _isCheckingPrototypeStatus
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _prototypeStatusSent
                                ? Icons.verified_rounded
                                : Icons.fact_check_rounded,
                          ),
                    label: Text(
                      _isCheckingPrototypeStatus
                          ? 'Esperando respuesta del equipo'
                          : _prototypeStatusSent
                          ? 'Revisar de nuevo'
                          : 'Revisar estado del equipo',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _CountCommandBar(
                    bridge: bridge,
                    busy:
                        _isSendingCommand ||
                        _isCheckingPrototypeStatus ||
                        _isCountCommandInFlight,
                    busyLabel: _countActionLabel,
                    startSent: _countOrderSent,
                    onPrepare: () => _sendCountCommand(
                      bridge,
                      command: 'PREPARARCONTEO',
                      inProgressLabel: 'Preparando conteo',
                    ),
                    onStart: () => _startCounting(bridge),
                    onStop: () => _sendCountCommand(
                      bridge,
                      command: 'DETENERCONTEO',
                      inProgressLabel: 'Deteniendo conteo',
                    ),
                    onStatus: () => _sendCountCommand(
                      bridge,
                      command: 'ESTADOCONTEO',
                      inProgressLabel: 'Consultando conteo',
                    ),
                    onResult: () => _sendCountCommand(
                      bridge,
                      command: 'RESULTADOCONTEO',
                      inProgressLabel: 'Consultando resultado',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    bridge.isConnected
                        ? 'La revisión consulta el equipo remoto por LoRa y muestra su estado aquí.'
                        : 'Primero conecta el teléfono al prototipo por Bluetooth.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  ),
                  if (bridge.latestJetsonStatus != null) ...[
                    const SizedBox(height: 12),
                    _JetsonStatusPanel(status: bridge.latestJetsonStatus!),
                  ],
                  if (bridge.latestCountStatus != null) ...[
                    const SizedBox(height: 12),
                    _CountStatusPanel(status: bridge.latestCountStatus!),
                  ],
                  if (_countOrderSent && bridge.latestCountStatus == null) ...[
                    const SizedBox(height: 12),
                    const _FriendlyMessage(
                      message:
                          'Orden enviada al equipo de campo. El conteo se inicia en la computadora.',
                      isError: false,
                    ),
                  ],
                  if (_bridgeError != null || bridge.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _FriendlyMessage(
                      message: _bridgeError ?? bridge.errorMessage!,
                      isError: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _FriendlyActivityList(events: bridge.events),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Opciones avanzadas'),
                    children: [
                      TextField(
                        controller: _commandController,
                        enabled: bridge.isConnected && !_isSendingCommand,
                        decoration: const InputDecoration(
                          labelText: 'Comando técnico',
                          hintText: 'Ej: ABRIR_COMPUERTA',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: bridge.isConnected
                            ? (_) => _sendCommand(bridge)
                            : null,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed:
                            !bridge.isConnected ||
                                _isSendingCommand ||
                                _isCheckingPrototypeStatus ||
                                _isCountCommandInFlight
                            ? null
                            : () => _sendCommand(bridge),
                        icon: _isSendingCommand
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSendingCommand
                              ? 'Enviando comando'
                              : 'Enviar comando técnico',
                        ),
                      ),
                      if (bridge.isConnected) ...[
                        const SizedBox(height: 12),
                        _DeviceRow(
                          label: 'Dispositivo',
                          value: bridge.deviceLabel,
                        ),
                        _DeviceRow(
                          label: 'Servicio BLE',
                          value: Esp32BleBridgeService.serviceUuid.str,
                        ),
                        _DeviceRow(
                          label: 'RX write',
                          value: Esp32BleBridgeService.rxCharacteristicUuid.str,
                        ),
                        _DeviceRow(
                          label: 'TX notify',
                          value: Esp32BleBridgeService.txCharacteristicUuid.str,
                        ),
                      ],
                      const SizedBox(height: 12),
                      _BridgeEventList(events: bridge.events),
                    ],
                  ),
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

class _CountCommandBar extends StatelessWidget {
  const _CountCommandBar({
    required this.bridge,
    required this.busy,
    required this.busyLabel,
    required this.startSent,
    required this.onPrepare,
    required this.onStart,
    required this.onStop,
    required this.onStatus,
    required this.onResult,
  });

  final Esp32BleBridgeService bridge;
  final bool busy;
  final String? busyLabel;
  final bool startSent;
  final VoidCallback onPrepare;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onStatus;
  final VoidCallback onResult;

  @override
  Widget build(BuildContext context) {
    final enabled = bridge.isConnected && !busy;

    Widget actionButton({
      required IconData icon,
      required String label,
      required VoidCallback onPressed,
      bool filled = false,
    }) {
      final child = Text(label);
      if (filled) {
        return FilledButton.icon(
          onPressed: enabled ? onPressed : null,
          icon: Icon(icon),
          label: child,
        );
      }
      return OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: child,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            actionButton(
              icon: Icons.task_alt_rounded,
              label: 'Preparar conteo',
              onPressed: onPrepare,
            ),
            actionButton(
              icon: Icons.play_arrow_rounded,
              label: startSent ? 'Iniciar de nuevo' : 'Iniciar conteo',
              onPressed: onStart,
              filled: true,
            ),
            actionButton(
              icon: Icons.stop_rounded,
              label: 'Detener conteo',
              onPressed: onStop,
            ),
            actionButton(
              icon: Icons.query_stats_rounded,
              label: 'Estado de conteo',
              onPressed: onStatus,
            ),
            actionButton(
              icon: Icons.assignment_turned_in_rounded,
              label: 'Resultado',
              onPressed: onResult,
            ),
          ],
        ),
        if (busyLabel != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(busyLabel!),
            ],
          ),
        ],
      ],
    );
  }
}

class _JetsonStatusPanel extends StatelessWidget {
  const _JetsonStatusPanel({required this.status});

  final JetsonStatusSnapshot status;

  @override
  Widget build(BuildContext context) {
    const healthyColor = Color(0xFF2E7D32);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: healthyColor.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.developer_board_rounded, color: healthyColor),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.hostname,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: healthyColor,
                      ),
                    ),
                    Text(
                      'Computadora de campo confirmada por LoRa',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.verified_rounded, color: healthyColor),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(
                icon: Icons.bolt_rounded,
                label: 'Modo energia',
                value: status.powerMode,
              ),
              _StatusPill(
                icon: Icons.schedule_rounded,
                label: 'Tiempo activo',
                value: status.uptime,
              ),
              _StatusPill(
                icon: Icons.thermostat_rounded,
                label: 'Temperatura',
                value: status.cpuTemp,
              ),
              _StatusPill(
                icon: Icons.memory_rounded,
                label: 'Memoria',
                value: status.memory,
              ),
              _StatusPill(
                icon: Icons.speed_rounded,
                label: 'Trabajo',
                value: status.loadAverage,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Actualizado ${formatDateTime(status.receivedAt)}',
            style: textTheme.bodySmall?.copyWith(color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _CountStatusPanel extends StatelessWidget {
  const _CountStatusPanel({required this.status});

  final JetsonCountSnapshot status;

  @override
  Widget build(BuildContext context) {
    final color = status.failed
        ? Colors.red.shade700
        : status.busy
        ? Colors.orange.shade800
        : const Color(0xFF2E7D32);
    final background = status.failed
        ? Colors.red.shade50
        : status.busy
        ? Colors.orange.shade50
        : const Color(0xFFE8F5E9);
    final title = switch (status.status) {
      'READY' => 'Equipo listo para contar',
      'STARTED' => 'Conteo iniciado',
      'RUNNING' => 'Conteo en marcha',
      'BUSY' => 'Conteo ya está en marcha',
      'STOPPING' => 'Deteniendo conteo',
      'STOPPED' => 'Conteo detenido',
      'RESULT' => 'Resultado de conteo',
      'ERROR' => 'Error en conteo',
      _ => 'Estado de conteo',
    };
    final icon = switch (status.status) {
      'READY' => Icons.task_alt_rounded,
      'STARTED' || 'RUNNING' || 'BUSY' => Icons.play_circle_fill_rounded,
      'STOPPING' => Icons.sync_rounded,
      'STOPPED' || 'RESULT' => Icons.assignment_turned_in_rounded,
      'ERROR' => Icons.error_outline_rounded,
      _ => Icons.info_outline_rounded,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
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
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(status.detail),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _StatusPill(
                      icon: Icons.tag_rounded,
                      label: 'Sesión',
                      value: status.sessionId,
                    ),
                    _StatusPill(
                      icon: Icons.schedule_rounded,
                      label: 'Tiempo',
                      value: '${status.elapsedSec}s',
                    ),
                    _StatusPill(
                      icon: Icons.pin_rounded,
                      label: 'PID',
                      value: status.pid,
                    ),
                    _StatusPill(
                      icon: Icons.numbers_rounded,
                      label: 'Conteo',
                      value: status.countLabel,
                    ),
                    if (status.reason.isNotEmpty)
                      _StatusPill(
                        icon: Icons.flag_rounded,
                        label: 'Motivo',
                        value: status.reason,
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Actualizado ${formatDateTime(status.receivedAt)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendlyMessage extends StatelessWidget {
  const _FriendlyMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? Colors.red.shade700 : const Color(0xFF2E7D32);
    final background = isError ? Colors.red.shade50 : const Color(0xFFE8F5E9);
    final icon = isError ? Icons.warning_amber_rounded : Icons.check_rounded;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _friendlyError(message),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _friendlyError(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('busy')) {
      return 'Ya hay una revision en curso. Espera unos segundos antes de volver a intentar.';
    }
    if (lower.contains('timeout') || lower.contains('no lleg')) {
      return 'No llego respuesta del equipo de campo. Acerca los modulos y revisa que ambos tengan energia.';
    }
    if (lower.contains('bluetooth') || lower.contains('ble')) {
      return 'No se pudo usar Bluetooth. Verifica que este activado y vuelve a conectar.';
    }
    return rawMessage;
  }
}

class _FriendlyActivityList extends StatelessWidget {
  const _FriendlyActivityList({required this.events});

  final List<Esp32BleBridgeEvent> events;

  @override
  Widget build(BuildContext context) {
    final items = events
        .map(_activityFromEvent)
        .whereType<_FriendlyActivity>()
        .take(4)
        .toList();

    if (items.isEmpty) {
      return const _FriendlyMessage(
        message: 'Listo para revisar el equipo.',
        isError: false,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ultimos pasos',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.icon, color: item.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item.text, style: TextStyle(color: item.color)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  _FriendlyActivity? _activityFromEvent(Esp32BleBridgeEvent event) {
    final message = event.message;

    if (message.startsWith('JETSON_STATUS:')) {
      return const _FriendlyActivity(
        text: 'El equipo de campo respondio correctamente.',
        icon: Icons.verified_rounded,
        color: Color(0xFF2E7D32),
      );
    }
    if (message.startsWith('JETSON_COUNT:')) {
      if (message.contains('status=ERROR')) {
        return const _FriendlyActivity(
          text: 'El equipo de campo reporto un error de conteo.',
          icon: Icons.error_outline_rounded,
          color: Colors.red,
        );
      }
      if (message.contains('status=READY')) {
        return const _FriendlyActivity(
          text: 'El equipo de campo esta listo para contar.',
          icon: Icons.task_alt_rounded,
          color: Color(0xFF2E7D32),
        );
      }
      if (message.contains('status=STOPPED') ||
          message.contains('status=RESULT')) {
        return const _FriendlyActivity(
          text: 'El equipo de campo devolvio el resultado de la sesion.',
          icon: Icons.assignment_turned_in_rounded,
          color: Color(0xFF2E7D32),
        );
      }
      if (message.contains('status=BUSY')) {
        return const _FriendlyActivity(
          text: 'Ya hay una sesion de conteo activa.',
          icon: Icons.info_outline_rounded,
          color: Colors.orange,
        );
      }
      return const _FriendlyActivity(
        text: 'El equipo de campo actualizo la sesion de conteo.',
        icon: Icons.play_circle_fill_rounded,
        color: Color(0xFF2E7D32),
      );
    }
    if (message.contains('esperando estado Jetson')) {
      return const _FriendlyActivity(
        text: 'Esperando respuesta del equipo de campo.',
        icon: Icons.sync_rounded,
        color: Colors.orange,
      );
    }
    if (message.contains('enviado por LoRa')) {
      return const _FriendlyActivity(
        text: 'Consulta enviada por radio.',
        icon: Icons.settings_input_antenna_rounded,
        color: Colors.blue,
      );
    }
    if (message.contains('BLE conectado') || message.contains('Conectado')) {
      return const _FriendlyActivity(
        text: 'Telefono conectado al prototipo.',
        icon: Icons.bluetooth_connected_rounded,
        color: Color(0xFF2E7D32),
      );
    }
    if (message.startsWith('ERROR:timeout')) {
      return const _FriendlyActivity(
        text: 'No llego respuesta. Revisa energia y distancia.',
        icon: Icons.warning_amber_rounded,
        color: Colors.red,
      );
    }
    if (message.startsWith('STATUS:respuesta LoRa con interferencia') ||
        message.startsWith('STATUS:paquete LoRa con interferencia')) {
      return const _FriendlyActivity(
        text: 'Se detecto interferencia de radio. Intenta otra vez.',
        icon: Icons.signal_cellular_connected_no_internet_4_bar_rounded,
        color: Colors.orange,
      );
    }

    return null;
  }
}

class _FriendlyActivity {
  const _FriendlyActivity({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 132),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
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

class _BleBridgeStatus extends StatelessWidget {
  const _BleBridgeStatus({required this.bridge});

  final Esp32BleBridgeService bridge;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String title;
    final String detail;

    switch (bridge.state) {
      case Esp32BleBridgeState.idle:
        color = Colors.grey;
        icon = Icons.bluetooth_rounded;
        title = 'BLE listo';
        detail = 'Presiona conectar para buscar BoviSense-Bridge.';
        break;
      case Esp32BleBridgeState.scanning:
        color = Colors.orange;
        icon = Icons.bluetooth_searching_rounded;
        title = 'Buscando puente BLE';
        detail = 'Escaneando el servicio BoviSense del ESP32.';
        break;
      case Esp32BleBridgeState.connecting:
        color = Colors.orange;
        icon = Icons.sync_rounded;
        title = 'Conectando';
        detail = 'Descubriendo servicio y characteristics RX/TX.';
        break;
      case Esp32BleBridgeState.connected:
        color = const Color(0xFF2E7D32);
        icon = Icons.check_circle_rounded;
        title = 'Puente conectado';
        detail = bridge.deviceLabel;
        break;
      case Esp32BleBridgeState.disconnected:
        color = Colors.red;
        icon = Icons.bluetooth_disabled_rounded;
        title = 'Puente desconectado';
        detail = 'No hay enlace BLE activo con el ESP32.';
        break;
      case Esp32BleBridgeState.permissionDenied:
        color = Colors.red;
        icon = Icons.lock_rounded;
        title = 'Permisos BLE denegados';
        detail = 'Autoriza Bluetooth para poder escanear y conectar.';
        break;
      case Esp32BleBridgeState.adapterOff:
        color = Colors.red;
        icon = Icons.bluetooth_disabled_rounded;
        title = 'Bluetooth apagado';
        detail = 'Activa Bluetooth en el teléfono.';
        break;
      case Esp32BleBridgeState.error:
        color = Colors.red;
        icon = Icons.error_rounded;
        title = 'Error BLE';
        detail = bridge.errorMessage ?? 'No se pudo usar Bluetooth.';
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

class _BridgeEventList extends StatelessWidget {
  const _BridgeEventList({required this.events});

  final List<Esp32BleBridgeEvent> events;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Text('Sin eventos BLE/LoRa todavía.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Eventos recientes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        ...events.take(8).map((event) {
          final color = switch (event.direction) {
            'APP_TX' => Colors.blue,
            'ESP_RX' => const Color(0xFF2E7D32),
            _ => Colors.grey,
          };
          final icon = switch (event.direction) {
            'APP_TX' => Icons.north_east_rounded,
            'ESP_RX' => Icons.south_west_rounded,
            _ => Icons.info_outline_rounded,
          };

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(event.message, style: TextStyle(color: color)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
