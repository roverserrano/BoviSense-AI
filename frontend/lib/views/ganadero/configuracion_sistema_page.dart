import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/configuracion_sistema_model.dart';
import '../../viewmodels/ganadero_view_model.dart';
import '../common/bovisense_ui.dart';
import '../common/session_actions.dart';
import 'ganadero_nav.dart';
import 'widgets/ganadero_widgets.dart';

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
  bool _applyingConfig = false;
  bool _hasUserEdited = false;
  String? _appliedConfigKey;

  @override
  void initState() {
    super.initState();
    _nombreFincaController.addListener(_markUserEdited);
    _cantidadEsperadaController.addListener(_markUserEdited);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_initialized) return;
    final vm = context.read<GanaderoViewModel>();
    _applyConfig(vm.configuracion);
    if (vm.dashboard == null && !vm.isLoadingDashboard) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(context.read<GanaderoViewModel>().loadDashboard());
        }
      });
    }

    _initialized = true;
  }

  @override
  void dispose() {
    _nombreFincaController.removeListener(_markUserEdited);
    _cantidadEsperadaController.removeListener(_markUserEdited);
    _nombreFincaController.dispose();
    _cantidadEsperadaController.dispose();
    super.dispose();
  }

  void _markUserEdited() {
    if (!_applyingConfig) _hasUserEdited = true;
  }

  void _applyConfig(ConfiguracionSistemaModel? config) {
    if (config == null) return;
    final key = '${config.nombreFinca}|${config.cantidadEsperada}';
    if (_appliedConfigKey == key || _hasUserEdited) return;

    _applyingConfig = true;
    _nombreFincaController.text = config.nombreFinca;
    _cantidadEsperadaController.text = config.cantidadEsperada.toString();
    _applyingConfig = false;
    _hasUserEdited = false;
    _appliedConfigKey = key;
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
      _hasUserEdited = false;
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
    _applyConfig(vm.configuracion);

    return Scaffold(
      appBar: AppTopBar(
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
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          children: [
            BoviCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Registro de la finca',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Completa estos datos para continuar.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nombreFincaController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la finca',
                      prefixIcon: Icon(Icons.home_work_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa el nombre de la finca';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _cantidadEsperadaController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad esperada de ganado',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                    onFieldSubmitted: (_) {
                      if (!vm.isSavingConfig) {
                        _save();
                      }
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Ingresa la cantidad esperada';
                      }
                      final parsed = int.tryParse(value.trim());
                      if (parsed == null || parsed <= 0) {
                        return 'La cantidad debe ser mayor a cero';
                      }
                      if (parsed > 1000000) {
                        return 'La cantidad no puede superar 1.000.000';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
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
