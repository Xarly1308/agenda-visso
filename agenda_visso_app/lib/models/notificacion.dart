class Notificacion {
  final String id;
  final String profesionalId;
  final String citaId;
  final String tipo;
  final String mensaje;
  final String subtitulo;
  final bool leida;
  final DateTime fechaCreacion;

  Notificacion({
    required this.id,
    required this.profesionalId,
    required this.citaId,
    required this.tipo,
    required this.mensaje,
    required this.subtitulo,
    this.leida = false,
    DateTime? fechaCreacion,
  }) : fechaCreacion = fechaCreacion ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'profesionalId': profesionalId,
        'citaId': citaId,
        'tipo': tipo,
        'mensaje': mensaje,
        'subtitulo': subtitulo,
        'leida': leida,
        'fechaCreacion': fechaCreacion.toIso8601String(),
      };

  factory Notificacion.fromMap(Map<String, dynamic> map) => Notificacion(
        id: map['id'] as String? ?? '',
        profesionalId: map['profesionalId'] as String? ?? '',
        citaId: map['citaId'] as String? ?? '',
        tipo: map['tipo'] as String? ?? '',
        mensaje: map['mensaje'] as String? ?? '',
        subtitulo: map['subtitulo'] as String? ?? '',
        leida: map['leida'] as bool? ?? false,
        fechaCreacion: DateTime.tryParse(map['fechaCreacion'] as String? ?? '') ?? DateTime.now(),
      );

  Notificacion copyWith({
    String? id,
    String? profesionalId,
    String? citaId,
    String? tipo,
    String? mensaje,
    String? subtitulo,
    bool? leida,
    DateTime? fechaCreacion,
  }) {
    return Notificacion(
      id: id ?? this.id,
      profesionalId: profesionalId ?? this.profesionalId,
      citaId: citaId ?? this.citaId,
      tipo: tipo ?? this.tipo,
      mensaje: mensaje ?? this.mensaje,
      subtitulo: subtitulo ?? this.subtitulo,
      leida: leida ?? this.leida,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }
}
