import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
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
  bool _isSendingCommand = false;
  bool _isCheckingPrototypeStatus = false;
  bool _prototypeStatusSent = false;
  bool _isSavingResult = false;
  bool _isStopping = false;
  bool _isRefreshingCount = false;
  bool _lastCountSaved = false;
  String? _bridgeError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GanaderoViewModel>().loadDashboard();
    });
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
        _bridgeError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  /// Pide encender el Bluetooth y, si el usuario acepta, sigue con la conexion.
  Future<void> _enableBluetoothAndConnect(Esp32BleBridgeService bridge) async {
    final enabled = await bridge.requestBluetoothEnable();
    if (!mounted) return;
    if (enabled) {
      await _connectBridge(bridge);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Activa el Bluetooth desde los ajustes del teléfono y vuelve a intentar.',
        ),
      ),
    );
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
    if (!mounted) return;
    if (!sent) {
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
    if (command == 'INICIARCONTEO') {
      setState(() => _lastCountSaved = false);
    }
    await _sendCommand(bridge, command);
  }

  /// Iniciar otro conteo descarta el resultado actual: se pide confirmacion
  /// porque el resultado todavia no esta guardado.
  Future<void> _confirmRepeatCount(Esp32BleBridgeService bridge) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Iniciar un conteo nuevo?'),
        content: const Text(
          'Este resultado todavía no se guardó. Si inicias otro conteo, se pierde.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Iniciar nuevo'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _sendCountCommand(bridge, 'INICIARCONTEO');
  }

  /// Detener solo se marca como "Deteniendo..." cuando lo pide el usuario.
  /// El sondeo automatico no debe cambiar el texto de los botones.
  Future<void> _stopCounting(Esp32BleBridgeService bridge) async {
    setState(() => _isStopping = true);
    try {
      await _sendCommand(bridge, 'DETENERCONTEO');
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  Future<void> _refreshCount(Esp32BleBridgeService bridge) async {
    setState(() => _isRefreshingCount = true);
    try {
      await _sendCommand(bridge, 'ESTADOCONTEO');
    } finally {
      if (mounted) setState(() => _isRefreshingCount = false);
    }
  }

  Future<bool> _waitForJetsonStatus(
    Esp32BleBridgeService bridge,
    DateTime requestedAt,
  ) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    while (mounted && DateTime.now().isBefore(deadline)) {
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
    Esp32BleBridgeService bridge,
    JetsonCountSnapshot? countStatus,
  ) async {
    if (_isSavingResult || countStatus == null || !countStatus.finalResult) {
      return;
    }

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
      proof: countStatus.proof!,
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

    // Solo aqui el conteo quedo realmente guardado.
    setState(() {
      _lastCountSaved = true;
      _bridgeError = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Conteo guardado. Ya puedes iniciar uno nuevo.'),
      ),
    );
    // Limpia el resultado para que al volver a esta vista aparezca la
    // secuencia de un conteo nuevo, no el resultado ya guardado.
    bridge.resetCountSession();
    vm.clearError();
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
    final countFailed = countStatus?.failed == true;

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
          else if (countFailed)
            _buildCountErrorState(bridge, countStatus)
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
    final vm = context.read<GanaderoViewModel>();
    // El backend rechaza INICIARCONTEO sin configuracion: se avisa antes de que
    // el ganadero intente contar y reciba un error tecnico.
    final needsConfig = vm.dashboard != null && vm.configuracion == null;
    if (needsConfig) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const StatusBar(
            status: SimpleStatusType.pending,
            label: 'Falta configurar tu finca',
            subtitle: 'Necesitamos el nombre y la cantidad esperada de ganado.',
          ),
          const SizedBox(height: 14),
          const AlertCard(
            title: 'Sin los datos de la finca no se puede contar',
            description:
                'El conteo compara los animales detectados con la cantidad esperada que registres aquí.',
            status: SimpleStatusType.pending,
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Configurar finca',
            onPressed: () => goToGanaderoTab(context, 1),
          ),
          const SizedBox(height: 12),
          TechnicalDetails(
            title: 'Detalles técnicos',
            lines: _technicalLines(bridge),
          ),
        ],
      );
    }

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
        StatusBar(
          status: _lastCountSaved
              ? SimpleStatusType.ready
              : SimpleStatusType.pending,
          label: _lastCountSaved
              ? 'Listo para un conteo nuevo'
              : 'Conecta el equipo',
          subtitle: _lastCountSaved
              ? 'El conteo anterior ya se guardó en el historial.'
              : 'Acerca el teléfono al equipo y revisa estado.',
        ),
        if (_lastCountSaved) ...[
          const SizedBox(height: 12),
          const AlertCard(
            title: 'Conteo guardado',
            description:
                'Revisa el historial para ver el detalle. Cuando estés listo, inicia otro conteo.',
            status: SimpleStatusType.ready,
          ),
        ],
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
          onTap: step2Active && !_isCheckingPrototypeStatus
              ? () => _sendPrototypeStatus(bridge)
              : null,
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
          onTap: step3Active && !_isSendingCommand
              ? () => _sendCountCommand(bridge, 'INICIARCONTEO')
              : null,
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
          label: _isStopping ? 'Deteniendo...' : 'Detener',
          onPressed: _isStopping ? null : () => _stopCounting(bridge),
        ),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: _isRefreshingCount ? 'Consultando...' : 'Actualizar conteo',
          onPressed: _isRefreshingCount ? null : () => _refreshCount(bridge),
        ),
        // Aviso fijo: deja claro que el refresco es automatico y que el cambio
        // de textos de los botones solo ocurre si el usuario actua.
        const SizedBox(height: 8),
        const Text(
          'El conteo se actualiza solo cada pocos segundos.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: GanaderoColors.muted),
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
              : () => _saveCountResult(vm, bridge, countStatus),
          isLoading: _isSavingResult,
        ),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: 'Nuevo conteo',
          onPressed: () => _confirmRepeatCount(bridge),
        ),
        const SizedBox(height: 12),
        TechnicalDetails(
          title: 'Detalles técnicos',
          lines: _technicalLines(bridge),
        ),
      ],
    );
  }

  Widget _buildCountErrorState(
    Esp32BleBridgeService bridge,
    JetsonCountSnapshot? countStatus,
  ) {
    final detail = countStatus?.detail.trim();
    final reason = countStatus?.reason.trim();
    final diagnostic = reason?.isNotEmpty == true
        ? reason!
        : detail?.isNotEmpty == true
        ? detail!
        : 'El equipo devolvió ERROR durante el conteo.';
    final busy = _isSendingCommand || _isCheckingPrototypeStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StatusBar(
          status: SimpleStatusType.error,
          label: 'El conteo se detuvo',
          subtitle: 'Revisa el equipo antes de iniciar otra sesión.',
        ),
        const SizedBox(height: 14),
        AlertCard(
          title: 'Falla del equipo',
          description: diagnostic,
          status: SimpleStatusType.error,
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: busy ? 'Consultando...' : 'Consultar equipo',
          onPressed: busy
              ? null
              // ESTADO no depende de la sesion: si la sesion murio al
              // reiniciarse la Jetson, este es el comando que si responde.
              : () => _sendPrototypeStatus(bridge),
          isLoading: busy,
        ),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: 'Iniciar nuevo conteo',
          onPressed: busy
              ? null
              : () => _sendCountCommand(bridge, 'INICIARCONTEO'),
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
    final isApiError = _isApiFailure(bridge);
    final failure = isApiError ? Esp32BleBridgeFailure.none : bridge.failure;
    final title = isApiError
        ? 'No se pudo preparar el comando'
        : _failureTitle(failure);
    final message =
        _bridgeError ??
        bridge.errorMessage ??
        'No se pudo conectar con el equipo.';
    final subtitle = isApiError ? message : _failureSubtitle(bridge, failure);
    final others = bridge.otherBluetoothDevices;

    return Column(
      children: [
        StatusBar(
          status: SimpleStatusType.error,
          label: title,
          subtitle: subtitle,
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
          child: Column(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 44,
                color: GanaderoColors.redText,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: GanaderoColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: GanaderoColors.muted,
                ),
                textAlign: TextAlign.center,
              ),
              if (others.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Bluetooth en uso por: ${others.take(4).join(', ')}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: GanaderoColors.muted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildConnectPrimaryAction(bridge, failure),
        const SizedBox(height: 10),
        OutlineActionButton(
          label: _needsPhoneSettings(failure)
              ? 'Abrir ajustes del teléfono'
              : 'Ayuda',
          onPressed: () {
            if (_needsPhoneSettings(failure)) {
              openAppSettings();
              return;
            }
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(_connectionHelp(failure))));
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

  bool _isApiFailure(Esp32BleBridgeService bridge) {
    final message = (_bridgeError ?? bridge.errorMessage ?? '').toLowerCase();
    return message.contains('backend') || message.contains('api');
  }

  /// Bluetooth apagado o permisos denegados se resuelven en los ajustes.
  bool _needsPhoneSettings(Esp32BleBridgeFailure failure) {
    return failure == Esp32BleBridgeFailure.bluetoothOff ||
        failure == Esp32BleBridgeFailure.permissionDenied;
  }

  String _failureTitle(Esp32BleBridgeFailure failure) {
    switch (failure) {
      case Esp32BleBridgeFailure.bluetoothOff:
        return 'Activa el Bluetooth';
      case Esp32BleBridgeFailure.bluetoothUnavailable:
        return 'Bluetooth no disponible';
      case Esp32BleBridgeFailure.permissionDenied:
        return 'Falta el permiso de Bluetooth';
      case Esp32BleBridgeFailure.deviceNotFound:
        return 'No se encontró el equipo';
      case Esp32BleBridgeFailure.bluetoothBusy:
        return 'El Bluetooth está ocupado';
      case Esp32BleBridgeFailure.connectionFailed:
        return 'No se pudo conectar con el equipo';
      case Esp32BleBridgeFailure.none:
        return 'No se pudo conectar con el equipo';
    }
  }

  String _failureSubtitle(
    Esp32BleBridgeService bridge,
    Esp32BleBridgeFailure failure,
  ) {
    if (failure == Esp32BleBridgeFailure.none) {
      return bridge.errorMessage ??
          'Acerca el teléfono al equipo y vuelve a intentar.';
    }
    return Esp32BleBridgeService.failureMessage(failure);
  }

  String _connectionHelp(Esp32BleBridgeFailure failure) {
    switch (failure) {
      case Esp32BleBridgeFailure.bluetoothOff:
        return 'BoviSense necesita el Bluetooth del teléfono para hablar con el equipo de conteo.';
      case Esp32BleBridgeFailure.permissionDenied:
        return 'Ajustes del teléfono > Aplicaciones > BoviSense > Permisos > Dispositivos cercanos.';
      case Esp32BleBridgeFailure.bluetoothBusy:
        return 'Desconecta audífonos, parlantes o reloj, y apaga y enciende el Bluetooth.';
      case Esp32BleBridgeFailure.deviceNotFound:
        return 'Revisa que el equipo de conteo esté encendido, con batería y a pocos metros.';
      case Esp32BleBridgeFailure.bluetoothUnavailable:
        return 'Reinicia el Bluetooth del teléfono y espera unos segundos.';
      case Esp32BleBridgeFailure.connectionFailed:
        return 'Apaga y enciende el equipo de conteo y acércate más al puente.';
      case Esp32BleBridgeFailure.none:
        return 'Verifica distancia, energía y que el Bluetooth esté activo.';
    }
  }

  Widget _buildConnectPrimaryAction(
    Esp32BleBridgeService bridge,
    Esp32BleBridgeFailure failure,
  ) {
    if (bridge.isBusy) {
      return const PrimaryButton(
        label: 'Conectando...',
        onPressed: null,
        isLoading: true,
      );
    }

    switch (failure) {
      case Esp32BleBridgeFailure.bluetoothOff:
        return PrimaryButton(
          label: 'Activar Bluetooth',
          onPressed: () => _enableBluetoothAndConnect(bridge),
        );
      case Esp32BleBridgeFailure.permissionDenied:
        return PrimaryButton(
          label: 'Abrir ajustes',
          onPressed: () => openAppSettings(),
        );
      case Esp32BleBridgeFailure.none:
      case Esp32BleBridgeFailure.bluetoothUnavailable:
      case Esp32BleBridgeFailure.deviceNotFound:
      case Esp32BleBridgeFailure.bluetoothBusy:
      case Esp32BleBridgeFailure.connectionFailed:
        return PrimaryButton(
          label: 'Reintentar',
          onPressed: () => _connectBridge(bridge),
        );
    }
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
        label: _isCheckingPrototypeStatus ? 'Revisando...' : 'Revisar estado',
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
    if (lower.contains('backend iot') ||
        lower.contains('api_base_url') ||
        lower.contains('ruta no encontrada')) {
      return rawMessage.replaceFirst('Exception: ', '');
    }
    if (lower.contains('timeout') || lower.contains('no lleg')) {
      return 'No se pudo conectar con el equipo. Acerca el teléfono al equipo y vuelve a intentar.';
    }
    if (lower.contains('bluetooth') || lower.contains('ble')) {
      return 'No se pudo conectar con el equipo. Activa Bluetooth y vuelve a intentar.';
    }
    return 'No se pudo conectar con el equipo.';
  }
}
