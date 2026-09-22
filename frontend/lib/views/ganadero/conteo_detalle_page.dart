import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
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
    _load();
  }

  void _load() {
    setState(() {
      _future = context.read<GanaderoViewModel>().obtenerConteoDetalle(
        widget.conteoId,
      );
    });
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
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                AlertCard(
                  title: 'No se pudo cargar el conteo',
                  description: snapshot.error.toString().replaceFirst(
                    'Exception: ',
                    '',
                  ),
                  status: SimpleStatusType.error,
                ),
                const SizedBox(height: 12),
                PrimaryButton(label: 'Reintentar', onPressed: _load),
                const SizedBox(height: 10),
                OutlineActionButton(
                  label: 'Volver',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: GanaderoColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: GanaderoColors.borderSoft,
                    width: 0.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DetailRow(
                      label: 'Fecha del conteo',
                      value: formatDateTime(conteo.fechaHoraInicio),
                    ),
                    const SizedBox(height: 6),
                    _DetailRow(
                      label: 'Cantidad esperada',
                      value: '${conteo.cantidadEsperada}',
                    ),
                    if (conteo.resumen.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        conteo.resumen,
                        style: const TextStyle(
                          fontSize: 13,
                          color: GanaderoColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: GanaderoColors.muted),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: GanaderoColors.textDark,
          ),
        ),
      ],
    );
  }
}
