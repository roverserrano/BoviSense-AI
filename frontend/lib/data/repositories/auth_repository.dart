import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/usuario_model.dart';

class AuthRepository {
  AuthRepository({
    required FirebaseAuth firebaseAuth,
    required FirebaseFirestore firestore,
  }) : _firebaseAuth = firebaseAuth,
       _firestore = firestore;

  final FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  Future<void> discardPersistedSession() async {
    if (_firebaseAuth.currentUser != null) {
      await _firebaseAuth.signOut();
    }
  }

  Future<UsuarioModel> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password.trim(),
      );

      final uid = credential.user?.uid;
      final authEmail = credential.user?.email?.toLowerCase() ?? '';

      if (uid == null) {
        throw Exception('No se pudo obtener el UID del usuario autenticado.');
      }

      final usuario = await _loadUserProfile(uid: uid, email: authEmail);

      if (usuario.estado.toLowerCase() != 'activo') {
        await _firebaseAuth.signOut();
        throw Exception('El usuario está inactivo.');
      }

      return usuario;
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapAuthError(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<UsuarioModel?> restoreSession() async {
    final currentUser = _firebaseAuth.currentUser;
    if (currentUser == null) return null;

    try {
      final usuario = await _loadUserProfile(
        uid: currentUser.uid,
        email: currentUser.email?.toLowerCase() ?? '',
      );

      if (usuario.estado.toLowerCase() != 'activo') {
        await _firebaseAuth.signOut();
        return null;
      }

      return usuario;
    } catch (e) {
      await _firebaseAuth.signOut();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception('No hay una sesión activa.');
    }

    final email = user.email?.trim();
    if (email == null || email.isEmpty) {
      throw Exception('No se encontró el correo de la cuenta.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapPasswordChangeError(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<UsuarioModel> _loadUserProfile({
    required String uid,
    required String email,
  }) async {
    final byUid = await _firestore.collection('Usuarios').doc(uid).get();

    if (byUid.exists && byUid.data() != null) {
      return UsuarioModel.fromJson(byUid.data()!, documentId: byUid.id);
    }

    final byEmail = await _firestore
        .collection('Usuarios')
        .where('correo', isEqualTo: email)
        .limit(1)
        .get();

    if (byEmail.docs.isNotEmpty) {
      throw Exception(
        'El perfil existe, pero el ID del documento no coincide con el UID de Authentication. Usa como ID: $uid',
      );
    }

    throw Exception(
      'No existe el documento del perfil en Firestore en la ruta Usuarios/$uid',
    );
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Correo o contraseña incorrectos.';
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'user-disabled':
        return 'La cuenta está deshabilitada.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      default:
        return e.message ?? 'No se pudo iniciar sesión.';
    }
  }

  String _mapPasswordChangeError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña actual es incorrecta.';
      case 'weak-password':
        return 'La nueva contraseña es demasiado débil.';
      case 'requires-recent-login':
        return 'Vuelve a iniciar sesión para cambiar la contraseña.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      default:
        return e.message ?? 'No se pudo cambiar la contraseña.';
    }
  }
}
