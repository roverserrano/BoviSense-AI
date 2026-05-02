import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../common/session_actions.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/ganadero_view_model.dart';
import 'conteo_detalle_page.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_design_system.dart';

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

  Future<void> _openStep() async {
    final vm = context.read<GanaderoViewModel>();
    if (vm.configuracion == null) {
      goToGanaderoTab(context, 1);
      return;
    }
    goToGanaderoTab(context, 2);
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final vm = context.watch<GanaderoViewModel>();
    final dashboard = vm.dashboard;
    final usuario = authVm.currentUser;
    final (nextTitle, nextDescription, nextButton) = _nextStepContent(vm);

    return Scaffold(
      appBar: GanaderoAppBar(
        titleText: 'Panel principal',
        actions: const [SessionActionsMenu()],
      ),
      bottomNavigationBar: GanaderoBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 0) return;
          goToGanaderoTab(context, index);
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await vm.loadDashboard();
          await vm.loadAlertas();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GanaderoColors.surfaceAlt,
                  child: const Icon(
                    Icons.person_rounded,
                    color: GanaderoColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${usuario?.nombreCompleto ?? 'Ganadero'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: GanaderoColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (usuario?.rol ?? 'usuario'),
                        style: const TextStyle(
                          fontSize: 13,
                          color: GanaderoColors.muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NextStepCard(
              title: nextTitle,
              description: nextDescription,
              buttonText: nextButton,
              onPressed: _openStep,
            ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Resumen'),
            if (vm.isLoadingDashboard && dashboard == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.25,
                children: [
                  StatCard(
                    number: '${dashboard?.cantidadConteos ?? 0}',
                    label: 'Conteos totales',
                    status: 'Terminado',
                  ),
                  StatCard(
                    number: '${dashboard?.alertasPendientes ?? 0}',
                    label: 'Alertas pendientes',
                    status: dashboard != null && dashboard.alertasPendientes > 0
                        ? 'Pendiente'
                        : 'Listo',
                  ),
                ],
              ),
            const SizedBox(height: 16),
            const SectionTitle(text: 'Historial reciente'),
            if (dashboard == null || dashboard.conteosRecientes.isEmpty)
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
                  'Aún no hay conteos registrados.',
                  style: TextStyle(
                    fontSize: 14,
                    color: GanaderoColors.textSecondary,
                  ),
                ),
              )
            else
              ...dashboard.conteosRecientes
                  .take(3)
                  .map(
                    (conteo) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: HistoryItem(
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
                  ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 8),
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

  (String, String, String) _nextStepContent(GanaderoViewModel vm) {
    if (vm.configuracion == null) {
      return (
        'Configura tu finca',
        'Completa los datos base para comparar tus conteos.',
        'Configurar ahora',
      );
    }

    final dispositivo = vm.dispositivo;
    if (dispositivo == null || dispositivo.estadoConexion != 'conectado') {
      return (
        'Conecta el equipo',
        'Acerca el teléfono al equipo y prepara la revisión.',
        'Abrir conteo',
      );
    }

    return (
      'El equipo está listo',
      'Puedes iniciar el conteo en este momento.',
      'Iniciar flujo',
    );
  }
}
