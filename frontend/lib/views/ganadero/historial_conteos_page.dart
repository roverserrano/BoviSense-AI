import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/ganadero_view_model.dart';
import '../common/session_actions.dart';
import 'conteo_detalle_page.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_design_system.dart';

class HistorialConteosPage extends StatefulWidget {
  const HistorialConteosPage({super.key});

  @override
  State<HistorialConteosPage> createState() => _HistorialConteosPageState();
}

class _HistorialConteosPageState extends State<HistorialConteosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final vm = context.read<GanaderoViewModel>();
      await vm.loadHistorial();
      await vm.loadAlertas();
      await vm.loadDashboard();
    });
  }

  Future<void> _markAlertRead(GanaderoViewModel vm, String alertaId) async {
    final ok = await vm.marcarAlertaLeida(alertaId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Alerta marcada como leída.'
              : (vm.errorMessage ?? 'No se pudo actualizar la alerta.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();
    final sorted = [...vm.historial]
      ..sort(
        (a, b) => (b.fechaHoraInicio ?? DateTime(1900)).compareTo(
          a.fechaHoraInicio ?? DateTime(1900),
        ),
      );
    // Primero lo que el ganadero tiene que atender.
    final alertas = [...vm.alertas]
      ..sort((a, b) {
        if (a.leida != b.leida) return a.leida ? 1 : -1;
        return b.fechaHora.compareTo(a.fechaHora);
      });
    final alertasPendientes =
        vm.dashboard?.alertasPendientes ??
        alertas.where((alerta) => !alerta.leida).length;

    return Scaffold(
      appBar: GanaderoAppBar(
        titleText: 'Historial',
        actions: const [SessionActionsMenu()],
      ),
      bottomNavigationBar: GanaderoBottomNavBar(
        currentIndex: 3,
        onTap: (index) {
          if (index == 3) return;
          goToGanaderoTab(context, index);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await vm.loadHistorial();
          await vm.loadAlertas();
          await vm.loadDashboard();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SectionTitle(text: 'Alertas'),
            if (vm.isLoadingAlertas && alertas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (alertas.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GanaderoColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GanaderoColors.borderSoft,
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'No tienes alertas. Tus conteos coinciden con lo esperado.',
                  style: TextStyle(
                    fontSize: 14,
                    color: GanaderoColors.textSecondary,
                  ),
                ),
              )
            else
              ...alertas.map(
                (alerta) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AlertItem(
                    alerta: alerta,
                    onMarkRead: () => _markAlertRead(vm, alerta.id),
                  ),
                ),
              ),
            if (vm.hasMoreAlertas)
              TextButton.icon(
                onPressed: vm.isLoadingAlertas
                    ? null
                    : () => vm.loadAlertas(more: true),
                icon: const Icon(Icons.expand_more),
                label: Text(
                  vm.isLoadingAlertas ? 'Cargando...' : 'Cargar más alertas',
                ),
              ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Conteos'),
            if (vm.isLoadingHistorial && sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (sorted.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GanaderoColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GanaderoColors.borderSoft,
                    width: 0.5,
                  ),
                ),
                child: const Text(
                  'Todavía no hay conteos registrados.',
                  style: TextStyle(
                    fontSize: 14,
                    color: GanaderoColors.textSecondary,
                  ),
                ),
              )
            else
              ...sorted.map(
                (conteo) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: HistoryItem(
                    conteo: conteo,
                    onTap: () {
                      final ganaderoVm = context.read<GanaderoViewModel>();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ChangeNotifierProvider<GanaderoViewModel>.value(
                                value: ganaderoVm,
                                child: ConteoDetallePage(conteoId: conteo.id),
                              ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            if (vm.hasMoreHistorial)
              TextButton.icon(
                onPressed: vm.isLoadingHistorial
                    ? null
                    : () => vm.loadHistorial(more: true),
                icon: const Icon(Icons.expand_more),
                label: Text(
                  vm.isLoadingHistorial ? 'Cargando...' : 'Cargar mas conteos',
                ),
              ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GanaderoColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: GanaderoColors.borderSoft,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Total de conteos: ${vm.dashboard?.cantidadConteos ?? sorted.length}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: GanaderoColors.textDark,
                      ),
                    ),
                  ),
                  Text(
                    'Alertas: $alertasPendientes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: GanaderoColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 10),
              AlertCard(
                title: 'Error',
                description: vm.errorMessage!,
                status: SimpleStatusType.error,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
