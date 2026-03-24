import 'model_utils.dart';

class ConteoModel {
  const ConteoModel({
    required this.id,
    required this.cantidadDetectada,
    required this.cantidadEsperada,
    required this.diferencia,
    required this.estadoConteo,
    required this.origen,
    required this.resumen,
    this.fechaHoraInicio,
    this.fechaHoraFin,
  });

  final String id;
  final int cantidadDetectada;
  final int cantidadEsperada;
  final int diferencia;
  final String estadoConteo;
  final String origen;
  final String resumen;
  final DateTime? fechaHoraInicio;
  final DateTime? fechaHoraFin;

  factory ConteoModel.fromJson(Map<String, dynamic> json) {
    return ConteoModel(
      id: (json['id'] ?? '').toString(),
      cantidadDetectada: jsonToInt(
        json['cantidad_detectada'] ?? json['cantidadDetectada'],
      ),
      cantidadEsperada: jsonToInt(
        json['cantidad_esperada'] ?? json['cantidadEsperada'],
      ),
      diferencia: jsonToInt(json['diferencia']),
      estadoConteo: (json['estado_conteo'] ?? json['estadoConteo'] ?? '')
          .toString(),
      origen: (json['origen'] ?? 'simulacion').toString(),
      resumen: (json['resumen'] ?? '').toString(),
      fechaHoraInicio: jsonToDate(
        json['fecha_hora_inicio'] ?? json['fechaHoraInicio'],
      ),
      fechaHoraFin: jsonToDate(json['fecha_hora_fin'] ?? json['fechaHoraFin']),
    );
  }
}
