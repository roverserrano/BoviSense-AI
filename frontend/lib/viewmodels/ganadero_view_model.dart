import 'package:flutter/foundation.dart';

import '../data/models/alerta_model.dart';
import '../data/models/configuracion_sistema_model.dart';
import '../data/models/conteo_model.dart';
import '../data/models/dispositivo_conteo_model.dart';
import '../data/models/ganadero_dashboard_model.dart';
import '../data/repositories/ganadero_repository.dart';

class GanaderoViewModel extends ChangeNotifier {
  GanaderoViewModel(this._repository);

  final GanaderoRepository _repository;

  GanaderoDashboardModel? _dashboard;
  List<ConteoModel> _historial = [];
  List<AlertaModel> _alertas = [];

  bool _isLoadingDashboard = false;
  bool _isLoadingHistorial = false;
  bool _isLoadingAlertas = false;
  bool _isSavingConfig = false;
  bool _isStartingCount = false;

  String? _errorMessage;

  GanaderoDashboardModel? get dashboard => _dashboard;
  List<ConteoModel> get historial => _historial;
  List<AlertaModel> get alertas => _alertas;
  ConfiguracionSistemaModel? get configuracion => _dashboard?.configuracion;
  DispositivoConteoModel? get dispositivo => _dashboard?.dispositivo;

  bool get isLoadingDashboard => _isLoadingDashboard;
  bool get isLoadingHistorial => _isLoadingHistorial;
  bool get isLoadingAlertas => _isLoadingAlertas;
  bool get isSavingConfig => _isSavingConfig;
  bool get isStartingCount => _isStartingCount;
  String? get errorMessage => _errorMessage;

  Future<void> loadDashboard() async {
    try {
      _isLoadingDashboard = true;
      _errorMessage = null;
      notifyListeners();

      _dashboard = await _repository.obtenerDashboard();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingDashboard = false;
      notifyListeners();
    }
  }

  Future<void> loadHistorial() async {
    try {
      _isLoadingHistorial = true;
      _errorMessage = null;
      notifyListeners();

      _historial = await _repository.listarConteos();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingHistorial = false;
      notifyListeners();
    }
  }

  Future<void> loadAlertas() async {
    try {
      _isLoadingAlertas = true;
      _errorMessage = null;
      notifyListeners();

      _alertas = await _repository.listarAlertas();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoadingAlertas = false;
      notifyListeners();
    }
  }

  Future<bool> guardarConfiguracion({
    required String nombreFinca,
    required int cantidadEsperada,
  }) async {
    try {
      _isSavingConfig = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.guardarConfiguracion(
        ConfiguracionSistemaModel(
          id: 'general',
          nombreFinca: nombreFinca,
          cantidadEsperada: cantidadEsperada,
        ),
      );

      await loadDashboard();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSavingConfig = false;
      notifyListeners();
    }
  }

  Future<ConteoModel?> iniciarConteo() async {
    try {
      _isStartingCount = true;
      _errorMessage = null;
      notifyListeners();

      final conteo = await _repository.iniciarConteo();
      await loadDashboard();
      await loadHistorial();
      await loadAlertas();
      return conteo;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return null;
    } finally {
      _isStartingCount = false;
      notifyListeners();
    }
  }

  Future<ConteoModel> obtenerConteoDetalle(String conteoId) {
    return _repository.obtenerConteoDetalle(conteoId);
  }

  Future<bool> marcarAlertaLeida(String alertaId) async {
    try {
      _errorMessage = null;
      notifyListeners();

      await _repository.marcarAlertaLeida(alertaId);
      await loadDashboard();
      await loadAlertas();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
