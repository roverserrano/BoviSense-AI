import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../viewmodels/ganadero_view_model.dart';

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
      Navigator.of(context).pop();
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
      appBar: AppBar(title: const Text('Configuración del sistema')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFE8F5E9),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Esta configuración será usada como base para los conteos del ganado. '
                  'Cuando se integre el prototipo con LoRa/ESP32, esta información seguirá siendo consumida desde el backend.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nombreFincaController,
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _cantidadEsperadaController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Cantidad esperada de ganado',
                prefixIcon: Icon(Icons.format_list_numbered_rounded),
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
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: vm.isSavingConfig ? null : _save,
              icon: vm.isSavingConfig
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                vm.isSavingConfig ? 'Guardando...' : 'Guardar configuración',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
