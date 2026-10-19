import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../data/services/esp32_ble_bridge_service.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../viewmodels/ganadero_view_model.dart';
import '../common/bovisense_ui.dart';
import '../common/session_actions.dart';
import 'conteo_detalle_page.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_widgets.dart';

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
    final bridge = context.watch<Esp32BleBridgeService>();
    final dashboard = vm.dashboard;
    final usuario = authVm.currentUser;
    final (nextTitle, nextDescription, nextButton) = _nextStepContent(
      vm,
      bridge,
    );

    return Scaffold(
      appBar: AppTopBar(
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
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryLight,
                  child: const Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hola, ${usuario?.nombreCorto ?? 'Ganadero'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        usuario?.rol ?? 'usuario',
                        style: AppTypography.caption,
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Semantics(
                    label: 'Cargando resumen',
                    child: const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  ),
                ),
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
                    statusColor:
                        dashboard != null && dashboard.alertasPendientes > 0
                        ? AppColors.warning
                        : AppColors.success,
                  ),
                ],
              ),
            if ((dashboard?.alertasPendientes ?? 0) > 0) ...[
              const SizedBox(height: 10),
              AlertCard(
                title:
                    'Tienes ${dashboard!.alertasPendientes} alerta(s) sin leer',
                description:
                    'Revisa los faltantes o excedentes detectados y márcalos como leídos.',
                status: SimpleStatusType.inProgress,
              ),
              const SizedBox(height: 8),
              OutlineActionButton(
                label: 'Ver alertas',
                onPressed: () => goToGanaderoTab(context, 3),
              ),
            ],
            const SizedBox(height: 16),
            const SectionTitle(text: 'Historial reciente'),
            if (dashboard == null || dashboard.conteosRecientes.isEmpty)
              const EmptyState(
                icon: Icons.history_rounded,
                title: 'Aún no hay conteos registrados',
                description:
                    'Cuando termines un conteo aparecerá aquí con su resultado.',
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
                          final ganaderoVm = context.read<GanaderoViewModel>();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangeNotifierProvider<
                                    GanaderoViewModel
                                  >.value(
                                    value: ganaderoVm,
                                    child: ConteoDetallePage(
                                      conteoId: conteo.id,
                                    ),
                                  ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
            if (vm.errorMessage != null) ...[
              const SizedBox(height: 8),
              StatusBanner(
                title: vm.errorMessage!,
                tone: StatusBannerTone.error,
              ),
            ],
          ],
        ),
      ),
    );
  }

  (String, String, String) _nextStepContent(
    GanaderoViewModel vm,
    Esp32BleBridgeService bridge,
  ) {
    if (vm.configuracion == null) {
      return (
        'Configura tu finca',
        'Completa los datos base para comparar tus conteos.',
        'Configurar ahora',
      );
    }

    // El estado real del puente lo conoce la app por BLE; el documento del
    // dispositivo en el backend queda desactualizado y nunca dice "conectado".
    if (!bridge.isConnected) {
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
