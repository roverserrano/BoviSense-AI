import '../models/alerta_model.dart';
import '../models/configuracion_sistema_model.dart';
import '../models/conteo_model.dart';
import '../models/dispositivo_conteo_model.dart';
import '../models/ganadero_dashboard_model.dart';
import '../services/api_client.dart';

class GanaderoRepository {
  GanaderoRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<GanaderoDashboardModel> obtenerDashboard() async {
    final response = await _apiClient.get('/api/ganadero/dashboard');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para el dashboard.');
    }

    return GanaderoDashboardModel.fromJson(response);
  }

  Future<ConfiguracionSistemaModel?> obtenerConfiguracion() async {
    final response = await _apiClient.get('/api/ganadero/configuracion');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para la configuración.');
    }

    final configuracion = response['configuracion'];
    if (configuracion == null) return null;

    return ConfiguracionSistemaModel.fromJson(
      Map<String, dynamic>.from(configuracion as Map),
    );
  }

  Future<ConfiguracionSistemaModel> guardarConfiguracion(
    ConfiguracionSistemaModel configuracion,
  ) async {
    final response = await _apiClient.put(
      '/api/ganadero/configuracion',
      configuracion.toJson(),
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Respuesta inválida del backend al guardar configuración.',
      );
    }

    return ConfiguracionSistemaModel.fromJson(
      Map<String, dynamic>.from(response['configuracion'] as Map),
    );
  }

  Future<DispositivoConteoModel> obtenerDispositivo() async {
    final response = await _apiClient.get('/api/ganadero/dispositivo');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para el dispositivo.');
    }

    return DispositivoConteoModel.fromJson(
      Map<String, dynamic>.from(response['dispositivo'] as Map),
    );
  }

  Future<ConteoModel> iniciarConteo() async {
    final response = await _apiClient.post('/api/ganadero/conteos', {});

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al iniciar conteo.');
    }

    return ConteoModel.fromJson(
      Map<String, dynamic>.from(response['conteo'] as Map),
    );
  }

  Future<List<ConteoModel>> listarConteos() async {
    final response = await _apiClient.get('/api/ganadero/conteos');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para el historial.');
    }

    final data = (response['conteos'] as List<dynamic>? ?? []);
    return data
        .map((e) => ConteoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConteoModel> obtenerConteoDetalle(String conteoId) async {
    final response = await _apiClient.get('/api/ganadero/conteos/$conteoId');

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Respuesta inválida del backend para el detalle del conteo.',
      );
    }

    return ConteoModel.fromJson(
      Map<String, dynamic>.from(response['conteo'] as Map),
    );
  }

  Future<List<AlertaModel>> listarAlertas() async {
    final response = await _apiClient.get('/api/ganadero/alertas');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para alertas.');
    }

    final data = (response['alertas'] as List<dynamic>? ?? []);
    return data
        .map((e) => AlertaModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> marcarAlertaLeida(String alertaId) async {
    await _apiClient.put('/api/ganadero/alertas/$alertaId/leer', {});
  }
}
