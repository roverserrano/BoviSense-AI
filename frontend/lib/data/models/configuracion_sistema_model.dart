import 'model_utils.dart';

class ConfiguracionSistemaModel {
  const ConfiguracionSistemaModel({
    required this.id,
    required this.nombreFinca,
    required this.cantidadEsperada,
    this.fechaActualizacion,
  });

  final String id;
  final String nombreFinca;
  final int cantidadEsperada;
  final DateTime? fechaActualizacion;

  factory ConfiguracionSistemaModel.fromJson(Map<String, dynamic> json) {
    return ConfiguracionSistemaModel(
      id: (json['id'] ?? 'general').toString(),
      nombreFinca: (json['nombre_finca'] ?? json['nombreFinca'] ?? '')
          .toString(),
      cantidadEsperada: jsonToInt(
        json['cantidad_esperada'] ?? json['cantidadEsperada'],
      ),
      fechaActualizacion: jsonToDate(
        json['fecha_actualizacion'] ?? json['fechaActualizacion'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nombre_finca': nombreFinca.trim(),
      'cantidad_esperada': cantidadEsperada,
    };
  }
}
