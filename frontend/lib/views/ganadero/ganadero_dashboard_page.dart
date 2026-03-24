import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/alerta_model.dart';
import '../../data/models/conteo_model.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/ganadero_view_model.dart';
import 'configuracion_sistema_page.dart';
import 'conteo_detalle_page.dart';
import 'estado_dispositivo_page.dart';
import 'historial_conteos_page.dart';

class GanaderoDashboardPage extends StatefulWidget {
  const GanaderoDashboardPage({super.key});

  @override
  State<GanaderoDashboardPage> createState() => _GanaderoDashboardPageState();
}

class _GanaderoDashboardPageState extends State<GanaderoDashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<GanaderoViewModel>();
      await vm.loadDashboard();
      await vm.loadAlertas();
    });
  }

  Future<void> _openConfiguracion() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ConfiguracionSistemaPage()));

    if (!mounted) return;
    await context.read<GanaderoViewModel>().loadDashboard();
  }

  Future<void> _openHistorial() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const HistorialConteosPage()));

    if (!mounted) return;
    await context.read<GanaderoViewModel>().loadDashboard();
  }

  Future<void> _openEstadoDispositivo() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const EstadoDispositivoPage()));

    if (!mounted) return;
    await context.read<GanaderoViewModel>().loadDashboard();
  }

  Future<void> _startCount() async {
    final vm = context.read<GanaderoViewModel>();

    if (vm.configuracion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Primero configura el sistema antes de iniciar un conteo.',
          ),
        ),
      );
      return;
    }

    final confirm =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Iniciar conteo'),
            content: Text(
              'Se iniciará un conteo para la finca "${vm.configuracion!.nombreFinca}" '
              'con cantidad esperada ${vm.configuracion!.cantidadEsperada}.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Iniciar'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm || !mounted) return;

    final conteo = await vm.iniciarConteo();

    if (!mounted) return;

    if (conteo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(vm.errorMessage ?? 'No se pudo iniciar el conteo.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Resultado del conteo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _InfoRow(
              label: 'Detectados',
              value: conteo.cantidadDetectada.toString(),
            ),
            _InfoRow(
              label: 'Esperados',
              value: conteo.cantidadEsperada.toString(),
            ),
            _InfoRow(
              label: 'Diferencia',
              value: formatSignedInt(conteo.diferencia),
            ),
            _InfoRow(label: 'Origen', value: conteo.origen),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<GanaderoViewModel>();
    final dashboard = vm.dashboard;
    final usuario = authVm.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel del ganadero'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => context.read<AuthViewModel>().logout(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.isStartingCount ? null : _startCount,
        icon: vm.isStartingCount
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.play_arrow_rounded),
        label: Text(vm.isStartingCount ? 'Contando...' : 'Iniciar conteo'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await vm.loadDashboard();
          await vm.loadAlertas();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFF2E7D32),
                  child: Icon(Icons.agriculture_rounded, color: Colors.white),
                ),
                title: Text(
                  'Bienvenido, ${usuario?.nombreCompleto ?? 'Ganadero'}',
                ),
                subtitle: Text(
                  dashboard?.configuracion?.nombreFinca.isNotEmpty == true
                      ? 'Finca: ${dashboard!.configuracion!.nombreFinca}'
                      : 'Configura tu finca para comenzar',
                ),
              ),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 12),
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
            ],
            const SizedBox(height: 12),
            if (vm.isLoadingDashboard && dashboard == null)
              const Padding(
                padding: EdgeInsets.only(top: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      title: 'Conteos',
                      value: '${dashboard?.cantidadConteos ?? 0}',
                      icon: Icons.analytics_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Alertas',
                      value: '${dashboard?.alertasPendientes ?? 0}',
                      icon: Icons.notification_important_outlined,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      title: 'Últ. dif.',
                      value: formatSignedInt(dashboard?.ultimaDiferencia ?? 0),
                      icon: Icons.balance_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _QuickActionButton(
                        icon: Icons.settings_suggest_rounded,
                        label: 'Configurar sistema',
                        onTap: _openConfiguracion,
                      ),
                      _QuickActionButton(
                        icon: Icons.history_rounded,
                        label: 'Historial',
                        onTap: _openHistorial,
                      ),
                      _QuickActionButton(
                        icon: Icons.memory_rounded,
                        label: 'Estado del prototipo',
                        onTap: _openEstadoDispositivo,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: dashboard?.configuracion == null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configuración del sistema',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Todavía no has configurado tu finca ni la cantidad esperada de ganado.',
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: _openConfiguracion,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                              ),
                              label: const Text('Configurar ahora'),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Configuración activa',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: 'Finca',
                              value: dashboard!.configuracion!.nombreFinca,
                            ),
                            _InfoRow(
                              label: 'Cantidad esperada',
                              value: dashboard!.configuracion!.cantidadEsperada
                                  .toString(),
                            ),
                            _InfoRow(
                              label: 'Actualizada',
                              value: formatDateTime(
                                dashboard!.configuracion!.fechaActualizacion,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: dashboard?.dispositivo == null
                      ? const Text('No hay información del dispositivo.')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prototipo de conteo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                Chip(
                                  label: Text(
                                    dashboard!.dispositivo!.estadoConexion
                                        .toUpperCase(),
                                  ),
                                  backgroundColor:
                                      dashboard!.dispositivo!.estadoConexion ==
                                          'conectado'
                                      ? Colors.green.shade50
                                      : Colors.orange.shade50,
                                ),
                                Chip(
                                  label: Text(
                                    dashboard!.dispositivo!.modoOperacion
                                        .toUpperCase(),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    'Batería ${(dashboard!.dispositivo!.nivelBateria * 100).toStringAsFixed(0)}%',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _InfoRow(
                              label: 'Tipo',
                              value: dashboard!.dispositivo!.tipoDispositivo,
                            ),
                            _InfoRow(
                              label: 'Versión modelo',
                              value: dashboard!.dispositivo!.versionModelo,
                            ),
                            _InfoRow(
                              label: 'Última sincronización',
                              value: formatDateTime(
                                dashboard!.dispositivo!.ultimaSincronizacion,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionTitle(
                title: 'Conteos recientes',
                actionLabel: 'Ver historial',
                onTap: _openHistorial,
              ),
              const SizedBox(height: 8),
              if ((dashboard?.conteosRecientes.isEmpty ?? true))
                const _EmptySection(
                  icon: Icons.analytics_outlined,
                  text: 'Aún no hay conteos registrados.',
                )
              else
                ...dashboard!.conteosRecientes.map(
                  (conteo) => _ConteoCard(
                    conteo: conteo,
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
              const SizedBox(height: 16),
              const Text(
                'Alertas recientes',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if ((dashboard?.alertasRecientes.isEmpty ?? true))
                const _EmptySection(
                  icon: Icons.notifications_none_rounded,
                  text: 'No tienes alertas recientes.',
                )
              else
                ...dashboard!.alertasRecientes.map(
                  (alerta) => _AlertaCard(
                    alerta: alerta,
                    onMarcarLeida: alerta.leida
                        ? null
                        : () async {
                            final ok = await context
                                .read<GanaderoViewModel>()
                                .marcarAlertaLeida(alerta.id);

                            if (!mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  ok
                                      ? 'Alerta marcada como leída.'
                                      : (vm.errorMessage ??
                                            'No se pudo actualizar la alerta.'),
                                ),
                              ),
                            );
                          },
                  ),
                ),
              const SizedBox(height: 90),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 110,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFF2E7D32)),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _ConteoCard extends StatelessWidget {
  const _ConteoCard({required this.conteo, required this.onTap});

  final ConteoModel conteo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diferenciaColor = conteo.diferencia == 0
        ? Colors.green
        : (conteo.diferencia > 0 ? Colors.blueGrey : Colors.red);

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2E7D32),
          child: const Icon(Icons.analytics_rounded, color: Colors.white),
        ),
        title: Text('Conteo ${formatDateTime(conteo.fechaHoraInicio)}'),
        subtitle: Text(
          'Detectados: ${conteo.cantidadDetectada} | Esperados: ${conteo.cantidadEsperada}',
        ),
        trailing: Text(
          formatSignedInt(conteo.diferencia),
          style: TextStyle(fontWeight: FontWeight.bold, color: diferenciaColor),
        ),
      ),
    );
  }
}

class _AlertaCard extends StatelessWidget {
  const _AlertaCard({required this.alerta, this.onMarcarLeida});

  final AlertaModel alerta;
  final VoidCallback? onMarcarLeida;

  @override
  Widget build(BuildContext context) {
    final color = alerta.nivel == 'alta'
        ? Colors.red.shade50
        : alerta.nivel == 'media'
        ? Colors.orange.shade50
        : Colors.blue.shade50;

    return Card(
      color: color,
      child: ListTile(
        leading: Icon(
          alerta.leida
              ? Icons.notifications_none_rounded
              : Icons.notification_important_rounded,
          color: alerta.leida ? Colors.grey : Colors.red,
        ),
        title: Text(alerta.mensaje),
        subtitle: Text(formatDateTime(alerta.fechaHora)),
        trailing: alerta.leida
            ? const Chip(label: Text('Leída'))
            : TextButton(onPressed: onMarcarLeida, child: const Text('Marcar')),
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 56, color: const Color(0xFF2E7D32)),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
