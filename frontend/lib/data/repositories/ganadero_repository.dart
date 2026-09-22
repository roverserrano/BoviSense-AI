import '../models/alerta_model.dart';
import '../models/configuracion_sistema_model.dart';
import '../models/conteo_model.dart';
import '../models/dispositivo_conteo_model.dart';
import '../models/ganadero_dashboard_model.dart';
import '../services/api_client.dart';

class GanaderoRepository {
  GanaderoRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;
  GanaderoRepository newSession() => GanaderoRepository(apiClient: _apiClient);
  String get apiBaseOrigin => _apiClient.baseOrigin;
  String? conteosCursor;
  String? alertasCursor;
  Future<Map<String, dynamic>> issueCommand(
    String command,
    String requestId,
  ) async => Map<String, dynamic>.from(
    await _apiClient.post('/api/ganadero/iot/comandos', {
      'command': command,
      'request_id': requestId,
    }),
  );
  Future<Map<String, dynamic>> verifyResponse(String frame) async =>
      Map<String, dynamic>.from(
        await _apiClient.post('/api/ganadero/iot/respuestas', {'frame': frame}),
      );

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

  Future<ConteoModel> registrarConteoReal({
    required String proof,
    required String sessionId,
  }) async {
    final response = await _apiClient.post('/api/ganadero/conteos', {
      'proof': proof,
      'session_id': sessionId,
    });

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al registrar conteo.');
    }

    return ConteoModel.fromJson(
      Map<String, dynamic>.from(response['conteo'] as Map),
    );
  }

  Future<List<ConteoModel>> listarConteos({String? cursor}) async {
    final response = await _apiClient.get(
      '/api/ganadero/conteos${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para el historial.');
    }

    conteosCursor = response['next_cursor'] as String?;
    final data = (response['conteos'] as List<dynamic>? ?? []);
    return data
        .map((e) => ConteoModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<ConteoModel> obtenerConteoDetalle(String conteoId) async {
    final response = await _apiClient.get(
      '/api/ganadero/conteos/${Uri.encodeComponent(conteoId)}',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception(
        'Respuesta inválida del backend para el detalle del conteo.',
      );
    }

    return ConteoModel.fromJson(
      Map<String, dynamic>.from(response['conteo'] as Map),
    );
  }

  Future<List<AlertaModel>> listarAlertas({String? cursor}) async {
    final response = await _apiClient.get(
      '/api/ganadero/alertas${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend para alertas.');
    }

    alertasCursor = response['next_cursor'] as String?;
    final data = (response['alertas'] as List<dynamic>? ?? []);
    return data
        .map((e) => AlertaModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> marcarAlertaLeida(String alertaId) async {
    await _apiClient.put(
      '/api/ganadero/alertas/${Uri.encodeComponent(alertaId)}/leer',
      {},
    );
  }
}
