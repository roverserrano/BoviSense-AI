import '../models/usuario_model.dart';
import '../services/api_client.dart';

class AdminUsuarioRepository {
  AdminUsuarioRepository({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<UsuarioModel>> listarUsuarios() async {
    final response = await _apiClient.get('/api/admin/usuarios');

    if (response is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del backend al listar usuarios.');
    }

    final usuariosRaw = response['usuarios'];
    if (usuariosRaw is! List) {
      return [];
    }

    return usuariosRaw
        .map(
          (e) => UsuarioModel.fromJson(
            Map<String, dynamic>.from(e as Map),
            documentId: (e as Map)['uid']?.toString(),
          ),
        )
        .toList();
  }

  Future<UsuarioModel> crearUsuario(UsuarioModel usuario) async {
    final response = await _apiClient.post(
      '/api/admin/usuarios',
      usuario.toJson(),
    );

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
