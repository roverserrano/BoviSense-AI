import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../data/models/conteo_model.dart';
import '../../viewmodels/ganadero_view_model.dart';

class ConteoDetallePage extends StatefulWidget {
  const ConteoDetallePage({super.key, required this.conteoId});

  final String conteoId;

  @override
  State<ConteoDetallePage> createState() => _ConteoDetallePageState();
}

class _ConteoDetallePageState extends State<ConteoDetallePage> {
  late Future<ConteoModel> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<GanaderoViewModel>().obtenerConteoDetalle(
      widget.conteoId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del conteo')),
      body: FutureBuilder<ConteoModel>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final conteo = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _DetailRow(
                        label: 'Inicio',
                        value: formatDateTime(conteo.fechaHoraInicio),
                      ),
                      _DetailRow(
                        label: 'Fin',
                        value: formatDateTime(conteo.fechaHoraFin),
                      ),
                      _DetailRow(
                        label: 'Cantidad detectada',
                        value: conteo.cantidadDetectada.toString(),
                      ),
                      _DetailRow(
                        label: 'Cantidad esperada',
                        value: conteo.cantidadEsperada.toString(),
                      ),
                      _DetailRow(
                        label: 'Diferencia',
                        value: formatSignedInt(conteo.diferencia),
                      ),
                      _DetailRow(label: 'Estado', value: conteo.estadoConteo),
                      _DetailRow(label: 'Origen', value: conteo.origen),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    conteo.resumen.isEmpty
                        ? 'Sin resumen disponible.'
                        : conteo.resumen,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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
