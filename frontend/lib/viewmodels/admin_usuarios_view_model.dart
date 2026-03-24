import 'package:flutter/foundation.dart';

import '../data/models/usuario_model.dart';
import '../data/repositories/admin_usuario_repository.dart';

class AdminUsuariosViewModel extends ChangeNotifier {
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

  Future<void> loadUsers() async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      _usuarios = await _repository.listarUsuarios();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createUser(UsuarioModel usuario) async {
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
