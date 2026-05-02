import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/esp32_ble_bridge_service.dart';
import '../../viewmodels/ganadero_view_model.dart';
import '../common/session_actions.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_design_system.dart';

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
  bool _prototypeStatusSent = false;
  bool _isSavingResult = false;
  String? _bridgeError;

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
      if (!mounted) return;
      setState(() {
        _bridgeError = 'No se pudo conectar con el equipo.';
      });
    }
  }

  Future<bool> _sendCommand(
    Esp32BleBridgeService bridge,
    String command,
  ) async {
    setState(() {
      _isSendingCommand = true;
      _bridgeError = null;
    });

    try {
      _commandController.text = command;
      await bridge.sendCommand(command);
      return true;
    } catch (e) {
      if (!mounted) return false;
      setState(() {
        _bridgeError = _friendlyError(e.toString());
      });
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCommand = false;
        });
      }
    }
  }

  Future<void> _sendPrototypeStatus(Esp32BleBridgeService bridge) async {
    final requestedAt = DateTime.now();

    setState(() {
      _isCheckingPrototypeStatus = true;
      _prototypeStatusSent = false;
      _bridgeError = null;
    });

    final sent = await _sendCommand(bridge, 'ESTADO');
    if (!mounted || !sent) {
      setState(() {
        _isCheckingPrototypeStatus = false;
      });
      return;
    }

    final ok = await _waitForJetsonStatus(bridge, requestedAt);
    if (!mounted) return;

    setState(() {
      _isCheckingPrototypeStatus = false;
      _prototypeStatusSent = ok;
      if (!ok) {
        _bridgeError =
            'No se pudo conectar con el equipo. Acerca el teléfono al equipo y vuelve a intentar.';
      }
    });
  }

  Future<void> _sendCountCommand(
    Esp32BleBridgeService bridge,
    String command,
  ) async {
    await _sendCommand(bridge, command);
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
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    return false;
  }

  Future<void> _saveCountResult(
    GanaderoViewModel vm,
    JetsonCountSnapshot? countStatus,
  ) async {
    if (countStatus == null) return;

    final countValue = int.tryParse(countStatus.count);
    if (countValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay un resultado válido para guardar.'),
        ),
      );
      return;
    }

    setState(() {
      _isSavingResult = true;
    });

    final saved = await vm.registrarConteoReal(
      cantidadDetectada: countValue,
      sessionId: countStatus.sessionId,
    );

    if (!mounted) return;

    setState(() {
      _isSavingResult = false;
    });

    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'No se pudo guardar el resultado.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resultado listo para guardar. Guardado con éxito.'),
      ),
    );
    goToGanaderoTab(context, 3);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();
    final bridge = context.watch<Esp32BleBridgeService>();
    final countStatus = bridge.latestCountStatus;

    final connectionError = _hasConnectionError(bridge);
    final running = countStatus?.running == true || countStatus?.busy == true;
    final hasResult = countStatus?.finalResult == true;

    return Scaffold(
      appBar: GanaderoAppBar(
        titleText: 'Conteo',
        actions: const [SessionActionsMenu()],
      ),
      bottomNavigationBar: GanaderoBottomNavBar(
        currentIndex: 2,
        onTap: (index) {
          if (index == 2) return;
          goToGanaderoTab(context, index);
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (connectionError)
            _buildConnectionErrorState(bridge)
          else if (running)
            _buildRunningState(bridge, countStatus)
          else if (hasResult)
            _buildResultState(vm, bridge, countStatus)
          else
            _buildFlowState(bridge, countStatus),
          if (_bridgeError != null) ...[
            const SizedBox(height: 12),
            AlertCard(
              title: 'Error',
              description: _bridgeError!,
              status: SimpleStatusType.error,
            ),
          ],
          if (vm.errorMessage != null) ...[
            const SizedBox(height: 12),
            AlertCard(
              title: 'Error',
              description: vm.errorMessage!,
              status: SimpleStatusType.error,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFlowState(
    Esp32BleBridgeService bridge,
    JetsonCountSnapshot? countStatus,
  ) {
    final connected = bridge.isConnected;
    final reviewed = _prototypeStatusSent || bridge.latestJetsonStatus != null;
    final started =
        countStatus?.started == true ||
        countStatus?.running == true ||
        countStatus?.finalResult == true;

    final step2Active = connected && !reviewed;
    final step3Active = connected && reviewed && !started;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBar(
          status: SimpleStatusType.pending,
          label: 'Conecta el equipo',
          subtitle: 'Acerca el teléfono al equipo y revisa estado.',
        ),
        const SizedBox(height: 14),
        const SectionTitle(text: 'Flujo de conexión y conteo'),
        StepFlowItem(
          title: '1. Conectar equipo',
          description: connected
              ? 'El equipo está listo.'
              : 'Conecta el equipo para iniciar el flujo.',
          state: connected ? StepStateType.completed : StepStateType.active,
          requiredAction: connected ? null : 'Acción: conectar',
        ),
        const SizedBox(height: 10),
        StepFlowItem(
          title: '2. Revisar estado',
          description: reviewed
              ? 'El equipo está listo.'
              : 'Consulta rápida para confirmar respuesta.',
          state: reviewed
              ? StepStateType.completed
              : step2Active
              ? StepStateType.active
              : StepStateType.pending,
          requiredAction: step2Active ? 'Acción: revisar estado' : null,
        ),
        const SizedBox(height: 10),
        StepFlowItem(
          title: '3. Iniciar conteo',
          description: started
              ? 'Conteo iniciado.'
              : 'Inicia cuando el equipo esté listo.',
          state: started
              ? StepStateType.completed
              : step3Active
              ? StepStateType.active
              : StepStateType.pending,
          requiredAction: step3Active ? 'Acción: iniciar' : null,
        ),
        const SizedBox(height: 10),
        StepFlowItem(
          title: '4. Conteo en marcha',
          description: 'El equipo cuenta en tiempo real.',
          state: StepStateType.pending,
        ),
        const SizedBox(height: 10),
        StepFlowItem(
          title: '5. Resultado',
          description: 'Guarda el resultado final.',
          state: StepStateType.pending,
        ),
        const SizedBox(height: 14),
        _buildDynamicPrimaryAction(bridge, reviewed, started),
        const SizedBox(height: 12),
        TechnicalDetails(
          title: 'Detalles técnicos',
          lines: _technicalLines(bridge),
        ),
      ],
    );
  }

  Widget _buildRunningState(
    Esp32BleBridgeService bridge,
    JetsonCountSnapshot? countStatus,
  ) {
    final countValue = int.tryParse(countStatus?.count ?? '0') ?? 0;
    final expected =
        context.read<GanaderoViewModel>().configuracion?.cantidadEsperada ?? 0;
    final diff = countValue - expected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBar(
          status: SimpleStatusType.inProgress,
          label: 'El conteo está en marcha',
          subtitle: 'Monitorea el total en tiempo real.',
        ),
        const SizedBox(height: 14),
        ResultHero(
          value: countValue,
          unit: 'animales detectados',
          expected: expected,
          diff: diff,
          status: statusLabel(SimpleStatusType.inProgress),
        ),
        const SizedBox(height: 10),
        const AlertCard(
          title: 'En curso',
          description: 'Puedes detener cuando finalice el paso por el lote.',
          status: SimpleStatusType.inProgress,
        ),
        const SizedBox(height: 12),
        StopButton(
          label: _isSendingCommand ? 'Deteniendo...' : 'Detener',
          onPressed: _isSendingCommand
              ? null
              : () => _sendCountCommand(bridge, 'DETENERCONTEO'),
        ),
        const SizedBox(height: 12),
        TechnicalDetails(
          title: 'Detalles técnicos',
          lines: _technicalLines(bridge),
        ),
      ],
    );
  }

  Widget _buildResultState(
    GanaderoViewModel vm,
    Esp32BleBridgeService bridge,
    JetsonCountSnapshot? countStatus,
  ) {
    final countValue = int.tryParse(countStatus?.count ?? '0') ?? 0;
    final expected = vm.configuracion?.cantidadEsperada ?? 0;
    final diff = countValue - expected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBar(
          status: SimpleStatusType.finished,
          label: 'Resultado listo para guardar',
          subtitle: 'Revisa y guarda el resultado final.',
        ),
        const SizedBox(height: 14),
        ResultHero(
          value: countValue,
          unit: 'animales detectados',
          expected: expected,
          diff: diff,
          status: statusLabel(SimpleStatusType.finished),
        ),
        if (diff != 0) ...[
          const SizedBox(height: 10),
          AlertCard(
            title: diff < 0 ? 'Faltante detectado' : 'Excedente detectado',
            description: diff < 0
                ? 'Se detectó un faltante de ${diff.abs()} animales.'
                : 'Se detectó un excedente de ${diff.abs()} animales.',
            status: diff < 0
                ? SimpleStatusType.inProgress
                : SimpleStatusType.error,
          ),
        ],
        const SizedBox(height: 12),
        PrimaryButton(
          label: _isSavingResult ? 'Guardando...' : 'Guardar',
          onPressed: _isSavingResult
              ? null
              : () => _saveCountResult(vm, countStatus),
          isLoading: _isSavingResult,
        ),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: 'Repetir',
          onPressed: () => _sendCountCommand(bridge, 'INICIARCONTEO'),
        ),
        const SizedBox(height: 12),
        TechnicalDetails(
          title: 'Detalles técnicos',
          lines: _technicalLines(bridge),
        ),
      ],
    );
  }

  Widget _buildConnectionErrorState(Esp32BleBridgeService bridge) {
    return Column(
      children: [
        const StatusBar(
          status: SimpleStatusType.error,
          label: 'No se pudo conectar con el equipo',
          subtitle: 'Acerca el teléfono al equipo y vuelve a intentar.',
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: GanaderoColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
          ),
          child: const Column(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 44,
                color: GanaderoColors.redText,
              ),
              SizedBox(height: 10),
              Text(
                'No se pudo conectar con el equipo',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GanaderoColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6),
              Text(
                'Acerca el teléfono al equipo y vuelve a intentar.',
                style: TextStyle(fontSize: 12, color: GanaderoColors.muted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: bridge.isBusy ? 'Conectando...' : 'Reintentar',
          onPressed: bridge.isBusy ? null : () => _connectBridge(bridge),
          isLoading: bridge.isBusy,
        ),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: 'Ayuda',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Verifica distancia, energía y Bluetooth activo.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        TechnicalDetails(
          title: 'Detalles técnicos',
          lines: _technicalLines(bridge),
        ),
      ],
    );
  }

  Widget _buildDynamicPrimaryAction(
    Esp32BleBridgeService bridge,
    bool reviewed,
    bool started,
  ) {
    if (bridge.isBusy) {
      return const PrimaryButton(
        label: 'Conectando...',
        onPressed: null,
        isLoading: true,
      );
    }

    if (!bridge.isConnected) {
      return PrimaryButton(
        label: 'Conectar el equipo',
        onPressed: () => _connectBridge(bridge),
      );
    }

    if (!reviewed) {
      return PrimaryButton(
        label: _isCheckingPrototypeStatus ? 'Revisando...' : 'Iniciar',
        onPressed: _isCheckingPrototypeStatus
            ? null
            : () => _sendPrototypeStatus(bridge),
        isLoading: _isCheckingPrototypeStatus,
      );
    }

    if (!started) {
      return PrimaryButton(
        label: _isSendingCommand ? 'Iniciando...' : 'Iniciar',
        onPressed: _isSendingCommand
            ? null
            : () => _sendCountCommand(bridge, 'INICIARCONTEO'),
        isLoading: _isSendingCommand,
      );
    }

    return PrimaryButton(
      label: _isSendingCommand ? 'Consultando...' : 'Guardar',
      onPressed: _isSendingCommand
          ? null
          : () => _sendCountCommand(bridge, 'RESULTADOCONTEO'),
      isLoading: _isSendingCommand,
    );
  }

  bool _hasConnectionError(Esp32BleBridgeService bridge) {
    return bridge.state == Esp32BleBridgeState.error ||
        bridge.state == Esp32BleBridgeState.permissionDenied ||
        bridge.state == Esp32BleBridgeState.adapterOff ||
        bridge.state == Esp32BleBridgeState.disconnected &&
            (bridge.errorMessage?.isNotEmpty == true || _bridgeError != null);
  }

  List<String> _technicalLines(Esp32BleBridgeService bridge) {
    final lines = <String>[];

    for (final event in bridge.events.take(8)) {
      lines.add('[${event.direction}] ${event.message}');
    }

    final jetsonStatus = bridge.latestJetsonStatus;
    if (jetsonStatus != null) {
      lines.insert(0, 'JETSON_STATUS ${jetsonStatus.rawMessage}');
    }

    final countStatus = bridge.latestCountStatus;
    if (countStatus != null) {
      lines.insert(0, 'JETSON_COUNT ${countStatus.rawMessage}');
    }

    return lines;
  }

  String _friendlyError(String rawMessage) {
    final lower = rawMessage.toLowerCase();
    if (lower.contains('timeout') || lower.contains('no lleg')) {
      return 'No se pudo conectar con el equipo. Acerca el teléfono al equipo y vuelve a intentar.';
    }
    if (lower.contains('bluetooth') || lower.contains('ble')) {
      return 'No se pudo conectar con el equipo. Activa Bluetooth y vuelve a intentar.';
    }
    return 'No se pudo conectar con el equipo.';
  }
}
