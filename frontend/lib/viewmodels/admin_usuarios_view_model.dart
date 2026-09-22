import 'session_notifier.dart';

import '../data/models/admin_resumen_model.dart';
import '../data/models/usuario_model.dart';
import '../data/repositories/admin_usuario_repository.dart';

class AdminUsuariosViewModel extends SessionNotifier {
  AdminUsuariosViewModel(this._repository);

  final AdminUsuarioRepository _repository;

  List<UsuarioModel> _usuarios = [];
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<UsuarioModel> get usuarios => _usuarios;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get errorMessage => _errorMessage;

  bool get hasMore => _repository.nextCursor != null;
  AdminResumenModel? get resumen => _repository.resumen;
  String? get creationNotice => _repository.creationNotice;

  /// La busqueda y los filtros de la app son locales: si quedan paginas sin
  /// cargar, un usuario podria no aparecer en los resultados. Se cargan bajo
  /// demanda, con un tope para no castigar la red si hay cientos de usuarios.
  Future<void> loadRemainingUsers({int maxPages = 10}) async {
    var page = 0;
    while (hasMore && page < maxPages && !disposed) {
      final previous = _usuarios.length;
      await loadUsers(more: true);
      if (_usuarios.length == previous) break; // no avanzo: cortar
      page++;
    }
  }

  Future<void> loadUsers({bool more = false}) async {
    if (disposed || _isLoading || (more && !hasMore)) return;
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      final items = await _repository.listarUsuarios(
        cursor: more ? _repository.nextCursor : null,
      );
      _usuarios = more ? [..._usuarios, ...items] : items;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser(UsuarioModel usuario) async {
    if (disposed || _isSaving) return false;
    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.crearUsuario(usuario);
      await loadUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> updateUser(UsuarioModel usuario) async {
    if (disposed || _isSaving) return false;
    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.actualizarUsuario(usuario);
      await loadUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<bool> deleteUser(String uid) async {
    if (disposed || _isSaving) return false;
    try {
      _isSaving = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.eliminarUsuario(uid);
      await loadUsers();
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
