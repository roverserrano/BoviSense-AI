import 'package:cloud_firestore/cloud_firestore.dart';

class UsuarioModel {
  const UsuarioModel({
    required this.uid,
    required this.nombre,
    required this.apellidos,
    required this.cedulaIdentidad,
    required this.correo,
    required this.telefono,
    required this.rol,
    required this.estado,
    this.fechaRegistro,
    this.operacionPendiente,
  });

  final String uid;
  final String nombre;
  final String apellidos;
  final int cedulaIdentidad;
  final String correo;
  final int telefono;
  final String rol;
  final String estado;
  final DateTime? fechaRegistro;

  /// Operacion administrativa a medias (alta/edicion/baja): mientras exista, el
  /// backend bloquea el acceso del usuario y hay que reintentar la operacion
  /// con los mismos datos.
  final String? operacionPendiente;

  String get nombreCompleto => '$nombre $apellidos'.trim();

  /// Nombre para saludar: nombre y apellido paterno ("Rover Serrano").
  ///
  /// En el modelo, `nombre` es un solo nombre y `apellidos` son el paterno y el
  /// materno; para el saludo solo se usa el primero.
  String get nombreCorto {
    final nombreSimple = nombre.trim();
    final apellidoPaterno = apellidos
        .trim()
        .split(RegExp(r'\s+'))
        .firstWhere((part) => part.isNotEmpty, orElse: () => '');

    if (apellidoPaterno.isEmpty) return nombreSimple;
    if (nombreSimple.isEmpty) return apellidoPaterno;
    return '$nombreSimple $apellidoPaterno';
  }

  factory UsuarioModel.fromJson(
    Map<String, dynamic> json, {
    String? documentId,
  }) {
    return UsuarioModel(
      uid: documentId ?? (json['uid'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      apellidos: (json['apellidos'] ?? json['apellido'] ?? '').toString(),
      cedulaIdentidad: _toInt(json['cedula_identidad'] ?? json['CI']),
      correo: (json['correo'] ?? '').toString(),
      telefono: _toInt(json['telefono']),
      rol: (json['rol'] ?? 'usuario').toString(),
      estado: (json['estado'] ?? 'activo').toString(),
      fechaRegistro: _toDate(json['fecha_registro'] ?? json['fechaRegistro']),
      operacionPendiente:
          (json['operacion_pendiente'] ?? json['operacionPendiente'])
              ?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'nombre': nombre.trim(),
      'apellidos': apellidos.trim(),
      'cedula_identidad': cedulaIdentidad,
      'correo': correo.trim().toLowerCase(),
      'telefono': telefono,
      'rol': rol.trim().toLowerCase(),
      'estado': estado.trim().toLowerCase(),
      'fecha_registro': fechaRegistro?.toIso8601String(),
    };
  }

  UsuarioModel copyWith({
    String? uid,
    String? nombre,
    String? apellidos,
    int? cedulaIdentidad,
    String? correo,
    int? telefono,
    String? rol,
    String? estado,
    DateTime? fechaRegistro,
    String? operacionPendiente,
  }) {
    return UsuarioModel(
      uid: uid ?? this.uid,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      cedulaIdentidad: cedulaIdentidad ?? this.cedulaIdentidad,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      rol: rol ?? this.rol,
      estado: estado ?? this.estado,
      fechaRegistro: fechaRegistro ?? this.fechaRegistro,
      operacionPendiente: operacionPendiente ?? this.operacionPendiente,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.tryParse(value.toString());
  }
}
