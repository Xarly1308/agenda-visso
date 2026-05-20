class Excepcion {
  final String id;
  final String profesionalId;
  final DateTime fecha;
  final String motivo;
  final String tipo;

  Excepcion({
    required this.id,
    required this.profesionalId,
    required this.fecha,
    required this.motivo,
    this.tipo = 'no_laborable',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'profesionalId': profesionalId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'motivo': motivo,
        'tipo': tipo,
      };

  factory Excepcion.fromMap(Map<String, dynamic> map) => Excepcion(
        id: map['id'] as String,
        profesionalId: map['profesionalId'] as String,
        fecha: DateTime.parse(map['fecha'] as String),
        motivo: map['motivo'] as String,
        tipo: map['tipo'] as String? ?? 'no_laborable',
      );

  Excepcion copyWith({
    String? id,
    String? profesionalId,
    DateTime? fecha,
    String? motivo,
    String? tipo,
  }) {
    return Excepcion(
      id: id ?? this.id,
      profesionalId: profesionalId ?? this.profesionalId,
      fecha: fecha ?? this.fecha,
      motivo: motivo ?? this.motivo,
      tipo: tipo ?? this.tipo,
    );
  }
}
