import 'alerta_model.dart';
import 'configuracion_sistema_model.dart';
import 'conteo_model.dart';
import 'dispositivo_conteo_model.dart';
import 'model_utils.dart';

class GanaderoDashboardModel {
  const GanaderoDashboardModel({
    required this.cantidadConteos,
    required this.alertasPendientes,
    required this.ultimaDiferencia,
    this.configuracion,
    this.dispositivo,
    this.ultimoConteo,
    this.conteosRecientes = const [],
    this.alertasRecientes = const [],
  });

  final ConfiguracionSistemaModel? configuracion;
  final DispositivoConteoModel? dispositivo;
  final ConteoModel? ultimoConteo;
  final List<ConteoModel> conteosRecientes;
  final List<AlertaModel> alertasRecientes;
  final int cantidadConteos;
  final int alertasPendientes;
  final int ultimaDiferencia;

  factory GanaderoDashboardModel.fromJson(Map<String, dynamic> json) {
    final conteosRaw = (json['conteos_recientes'] as List<dynamic>? ?? []);
    final alertasRaw = (json['alertas_recientes'] as List<dynamic>? ?? []);

    return GanaderoDashboardModel(
      configuracion: json['configuracion'] is Map<String, dynamic>
          ? ConfiguracionSistemaModel.fromJson(
              json['configuracion'] as Map<String, dynamic>,
            )
          : null,
      dispositivo: json['dispositivo'] is Map<String, dynamic>
          ? DispositivoConteoModel.fromJson(
              json['dispositivo'] as Map<String, dynamic>,
            )
          : null,
      ultimoConteo: json['ultimo_conteo'] is Map<String, dynamic>
          ? ConteoModel.fromJson(json['ultimo_conteo'] as Map<String, dynamic>)
          : null,
      conteosRecientes: conteosRaw
          .map((e) => ConteoModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      alertasRecientes: alertasRaw
          .map((e) => AlertaModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      cantidadConteos: jsonToInt(json['cantidad_conteos']),
      alertasPendientes: jsonToInt(json['alertas_pendientes']),
      ultimaDiferencia: jsonToInt(json['ultima_diferencia']),
    );
  }
}
