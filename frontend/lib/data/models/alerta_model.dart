import 'model_utils.dart';

class AlertaModel {
  const AlertaModel({
    required this.id,
    required this.mensaje,
    required this.fechaHora,
    required this.leida,
    required this.nivel,
  });

  final String id;
  final String mensaje;
  final DateTime fechaHora;
  final bool leida;
  final String nivel;

  factory AlertaModel.fromJson(Map<String, dynamic> json) {
    return AlertaModel(
      id: (json['id'] ?? '').toString(),
      mensaje: (json['mensaje'] ?? '').toString(),
      fechaHora: jsonToDate(json['fecha_hora'] ?? json['fechaHora']) ?? DateTime.now(),
      leida: json['leida'] == true,
      nivel: (json['nivel'] ?? 'media').toString(),
    );
  }
}
