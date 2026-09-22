import 'dart:convert';
import '../../core/utils/request_id.dart';

import '../models/admin_resumen_model.dart';
import '../models/usuario_model.dart';
import '../services/api_client.dart';

class AdminUsuarioRepository {
  AdminUsuarioRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;
  AdminUsuarioRepository newSession() =>
      AdminUsuarioRepository(apiClient: _apiClient);
  String? nextCursor;
  String? creationNotice;
  AdminResumenModel? resumen;
  String? _pendingPayload;
  String? _pendingId;

  Future<List<UsuarioModel>> listarUsuarios({String? cursor}) async {
    final response = await _apiClient.get(
      '/api/admin/usuarios${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al listar usuarios.');
    }

    nextCursor = response['next_cursor'] as String?;
    final resumenRaw = response['resumen'];
    if (resumenRaw is Map) {
      resumen = AdminResumenModel.fromJson(
        Map<String, dynamic>.from(resumenRaw),
      );
    }
    final usuariosRaw = response['usuarios'];
    if (usuariosRaw is! List) {
      return [];
    }

    return usuariosRaw
        .map(
          (e) => UsuarioModel.fromJson(
            Map<String, dynamic>.from(e as Map),
            documentId: e['uid']?.toString(),
          ),
        )
        .toList();
  }

  Future<UsuarioModel> crearUsuario(UsuarioModel usuario) async {
    final payload = jsonEncode(usuario.toJson());
    if (_pendingPayload != payload) {
      _pendingPayload = payload;
      _pendingId = newRequestId();
    }
    final response = await _apiClient.post('/api/admin/usuarios', {
      ...usuario.toJson(),
      'request_id': _pendingId,
    });
    _pendingPayload = null;
    creationNotice = response is Map ? response['message'] as String? : null;

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al crear usuario.');
    }

    final usuarioRaw = response['usuario'];
    if (usuarioRaw is! Map) {
      throw Exception('El backend no devolvió el usuario creado.');
    }

    return UsuarioModel.fromJson(
      Map<String, dynamic>.from(usuarioRaw),
      documentId: usuarioRaw['uid']?.toString(),
    );
  }

  Future<UsuarioModel> actualizarUsuario(UsuarioModel usuario) async {
    final response = await _apiClient.put(
      '/api/admin/usuarios/${usuario.uid}',
      usuario.toJson(),
    );

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al actualizar usuario.');
    }

    final usuarioRaw = response['usuario'];
    if (usuarioRaw is! Map) {
      throw Exception('El backend no devolvió el usuario actualizado.');
    }

    return UsuarioModel.fromJson(
      Map<String, dynamic>.from(usuarioRaw),
      documentId: usuarioRaw['uid']?.toString(),
    );
  }

  Future<void> eliminarUsuario(String uid) async {
    await _apiClient.delete('/api/admin/usuarios/$uid');
  }
}
