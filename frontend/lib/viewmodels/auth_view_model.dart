import 'package:flutter/foundation.dart';

import '../data/models/usuario_model.dart';
import '../data/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository);

  final AuthRepository _repository;

  UsuarioModel? _currentUser;
  bool _isLoading = false;
  bool _isInitializing = true;
  bool _isChangingPassword = false;
  bool _isSendingPasswordReset = false;
  String? _errorMessage;

  UsuarioModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isInitializing => _isInitializing;
  bool get isChangingPassword => _isChangingPassword;
  bool get isSendingPasswordReset => _isSendingPasswordReset;
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

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      _isChangingPassword = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  Future<bool> requestPasswordReset({required String email}) async {
    try {
      _isSendingPasswordReset = true;
      _errorMessage = null;
      notifyListeners();

      await _repository.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      _isSendingPasswordReset = false;
      notifyListeners();
    }
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
