class AuditLog {
  final String id;
  final String accion;
  final String coleccion;
  final String? documentoId;
  final String usuarioId;
  final String usuarioNombre;
  final String? franquiciaId;
  final DateTime timestamp;
  final String? detalles;

  AuditLog({
    required this.id,
    required this.accion,
    required this.coleccion,
    this.documentoId,
    required this.usuarioId,
    required this.usuarioNombre,
    this.franquiciaId,
    required this.timestamp,
    this.detalles,
  });

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] as String? ?? '',
      accion: map['accion'] as String? ?? '',
      coleccion: map['coleccion'] as String? ?? '',
      documentoId: map['documentoId'] as String?,
      usuarioId: map['usuarioId'] as String? ?? '',
      usuarioNombre: map['usuarioNombre'] as String? ?? '',
      franquiciaId: map['franquiciaId'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      detalles: map['detalles'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'accion': accion,
      'coleccion': coleccion,
      'documentoId': documentoId,
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
      'franquiciaId': franquiciaId,
      'timestamp': timestamp.toIso8601String(),
      'detalles': detalles,
    };
  }
}
