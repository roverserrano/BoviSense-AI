import 'model_utils.dart';

class DispositivoConteoModel {
  const DispositivoConteoModel({
    required this.id,
    required this.nombreDispositivo,
    required this.tipoDispositivo,
    required this.estadoConexion,
    required this.versionModelo,
    required this.estadoOperativo,
    required this.nivelBateria,
    required this.coordenadasGps,
    required this.modoOperacion,
    this.ultimaSincronizacion,
  });

  final String id;
  final String nombreDispositivo;
  final String tipoDispositivo;
  final String estadoConexion;
  final String versionModelo;
  final String estadoOperativo;
  final double nivelBateria;
  final String coordenadasGps;
  final String modoOperacion;
  final DateTime? ultimaSincronizacion;

  factory DispositivoConteoModel.fromJson(Map<String, dynamic> json) {
    return DispositivoConteoModel(
      id: (json['id'] ?? 'prototipo').toString(),
      nombreDispositivo:
          (json['nombre_dispositivo'] ?? json['nombreDispositivo'] ?? '')
              .toString(),
      tipoDispositivo:
          (json['tipo_dispositivo'] ?? json['tipoDispositivo'] ?? '')
              .toString(),
      estadoConexion:
          (json['estado_conexion'] ?? json['estadoConexion'] ?? 'desconocido')
              .toString(),
      versionModelo: (json['version_modelo'] ?? json['versionModelo'] ?? '')
          .toString(),
      estadoOperativo:
          (json['estado_operativo'] ?? json['estadoOperativo'] ?? '')
              .toString(),
      nivelBateria: jsonToDouble(json['nivel_bateria'] ?? json['nivelBateria']),
      coordenadasGps: (json['coordenadas_gps'] ?? json['coordenadasGPS'] ?? '')
          .toString(),
      modoOperacion:
          (json['modo_operacion'] ?? json['modoOperacion'] ?? 'simulacion')
              .toString(),
      ultimaSincronizacion: jsonToDate(
        json['ultima_sincronizacion'] ?? json['ultimaSincronizacion'],
      ),
    );
  }
}
