import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/conteo_model.dart';
import '../../viewmodels/ganadero_view_model.dart';
import '../common/session_actions.dart';
import 'widgets/ganadero_design_system.dart';

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
      appBar: GanaderoAppBar(
        titleText: 'Resultado de conteo',
        actions: const [SessionActionsMenu()],
      ),
      body: FutureBuilder<ConteoModel>(
        future: _future,
        builder: (_, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AlertCard(
                  title: 'Error',
                  description: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  status: SimpleStatusType.error,
                ),
              ),
            );
          }

          final conteo = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ResultHero(
                value: conteo.cantidadDetectada,
                unit: 'animales detectados',
                expected: conteo.cantidadEsperada,
                diff: conteo.diferencia,
                status: conteo.diferencia == 0
                    ? 'Terminado'
                    : conteo.diferencia < 0
                    ? 'Faltante'
                    : 'Excedente',
              ),
              const SizedBox(height: 14),
              OutlineActionButton(
                label: 'Volver',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      ),
    );
  }
}
