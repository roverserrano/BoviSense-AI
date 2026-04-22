import 'package:flutter/foundation.dart';

import '../data/models/usuario_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);

  final AuthRepository _repository;

  UsuarioModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  String? _errorMessage;

  UsuarioModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.rol.toLowerCase() == 'administrador';

  Future<void> initializeSession() async {
    try {
      await _repository.discardPersistedSession();
      _currentUser = null;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> restoreSession() async {
    try {
      _currentUser = await _repository.restoreSession();
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login({required String email, required String password}) async {
    try {
      _setLoading(true);
      _errorMessage = null;

      _currentUser = await _repository.signIn(email: email, password: password);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    await _repository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  Future<void> closeAppSession() async {
    if (_currentUser == null) {
      await _repository.discardPersistedSession();
      return;
    }

    await _repository.signOut();
    _currentUser = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
