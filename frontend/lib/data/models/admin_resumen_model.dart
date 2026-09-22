/// Conteos reales del sistema de usuarios, calculados por el backend.
///
/// No se derivan de la lista cargada: con paginacion serian incorrectos.
class AdminResumenModel {
  const AdminResumenModel({
    required this.total,
    required this.activos,
    required this.inactivos,
    required this.administradores,
  });

  final int total;
  final int activos;
  final int inactivos;
  final int administradores;

  factory AdminResumenModel.fromJson(Map<String, dynamic> json) {
    int toInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return AdminResumenModel(
      total: toInt(json['total']),
      activos: toInt(json['activos']),
      inactivos: toInt(json['inactivos']),
      administradores: toInt(json['administradores']),
    );
  }
}
