import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/ganadero_view_model.dart';
import '../common/session_actions.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_design_system.dart';

class ConfiguracionSistemaPage extends StatefulWidget {
  const ConfiguracionSistemaPage({super.key});

  @override
  State<ConfiguracionSistemaPage> createState() =>
      _ConfiguracionSistemaPageState();
}

class _ConfiguracionSistemaPageState extends State<ConfiguracionSistemaPage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreFincaController = TextEditingController();
  final _cantidadEsperadaController = TextEditingController();

  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    final vm = context.read<GanaderoViewModel>();
    final config = vm.configuracion;

    if (config != null) {
      _nombreFincaController.text = config.nombreFinca;
      _cantidadEsperadaController.text = config.cantidadEsperada.toString();
    }

    _initialized = true;
  }

  @override
  void dispose() {
    _nombreFincaController.dispose();
    _cantidadEsperadaController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<GanaderoViewModel>();
    final ok = await vm.guardarConfiguracion(
      nombreFinca: _nombreFincaController.text.trim(),
      cantidadEsperada: int.parse(_cantidadEsperadaController.text.trim()),
    );

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada correctamente.')),
      );
      goToGanaderoTab(context, 0);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          vm.errorMessage ?? 'No se pudo guardar la configuración.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<GanaderoViewModel>();

    return Scaffold(
      appBar: GanaderoAppBar(
        titleText: 'Finca',
        actions: const [SessionActionsMenu()],
      ),
      bottomNavigationBar: GanaderoBottomNavBar(
        currentIndex: 1,
        onTap: (index) {
          if (index == 1) return;
          goToGanaderoTab(context, index);
        },
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          children: [
            _GroupCard(
              child: Column(
                //crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _FormHeader(
                    title: 'Registro de la finca',
                    subtitle: 'Completa estos datos para continuar.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _nombreFincaController,
                    decoration: const InputDecoration(
                      hintText: 'Nombre de la finca',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre de la finca';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cantidadEsperadaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      hintText: 'Cantidad esperada de ganado',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la cantidad esperada';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'La cantidad debe ser mayor a cero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: vm.isSavingConfig ? 'Guardando...' : 'Guardar',
                    onPressed: vm.isSavingConfig ? null : _save,
                    isLoading: vm.isSavingConfig,
                  ),
                  const SizedBox(height: 10),
                  OutlineActionButton(
                    label: 'Cancelar',
                    onPressed: () => goToGanaderoTab(context, 0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: GanaderoColors.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 12,
            color: GanaderoColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GanaderoColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GanaderoColors.borderSoft, width: 0.5),
      ),
      child: child,
    );
  }
}
