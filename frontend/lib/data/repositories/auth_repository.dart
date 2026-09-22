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
        password: password,
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
      await _firebaseAuth.signOut();
      throw Exception(_mapAuthError(e));
    } on FirebaseException catch (e) {
      // Firestore: distinguir falta de red de un problema de permisos o de datos.
      await _firebaseAuth.signOut();
      throw Exception(_mapFirestoreError(e));
    } on Exception catch (e) {
      await _firebaseAuth.signOut();
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      throw Exception(
        message.isEmpty
            ? 'No se pudo cargar el perfil autorizado. Contacta al administrador.'
            : message,
      );
    } catch (e) {
      await _firebaseAuth.signOut();
      throw Exception(
        'No se pudo cargar el perfil autorizado. Revisa tu conexion o contacta al administrador.',
      );
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

  Future<void> sendPasswordResetEmail({required String email}) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty) {
      throw Exception('Ingresa un correo válido.');
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (e) {
      // Evitamos exponer si el correo existe o no para no facilitar enumeración.
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        return;
      }
      throw Exception(_mapPasswordResetError(e));
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<UsuarioModel> _loadUserProfile({
    required String uid,
    required String email,
  }) async {
    final byUid = await _firestore
        .collection('Usuarios')
        .doc(uid)
        .get(const GetOptions(source: Source.server));

    if (byUid.exists && byUid.data() != null) {
      return UsuarioModel.fromJson(byUid.data()!, documentId: byUid.id);
    }

    throw Exception('El perfil no esta disponible. Contacta al administrador.');
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
      case 'network-request-failed':
        return 'Sin conexión con Firebase. Revisa el internet del teléfono e intenta nuevamente.';
      default:
        return e.message ?? 'No se pudo iniciar sesión.';
    }
  }

  String _mapFirestoreError(FirebaseException e) {
    switch (e.code) {
      case 'unavailable':
      case 'network-request-failed':
        return 'Sin conexión con Firebase. Revisa el internet del teléfono e intenta nuevamente.';
      case 'permission-denied':
      case 'not-found':
        return 'El perfil no está disponible. Contacta al administrador.';
      case 'deadline-exceeded':
        return 'Firebase tardó demasiado. Intenta nuevamente.';
      default:
        return 'No se pudo cargar el perfil autorizado (${e.code}).';
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

  String _mapPasswordResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'El correo no es válido.';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde.';
      case 'network-request-failed':
        return 'No hay conexión. Revisa internet e intenta nuevamente.';
      default:
        return e.message ?? 'No se pudo procesar la recuperación.';
    }
  }
}
