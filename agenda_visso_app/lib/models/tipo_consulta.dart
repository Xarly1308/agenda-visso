class TipoConsulta {
  final String id;
  final String nombre;
  final bool activo;

  TipoConsulta({
    required this.id,
    required this.nombre,
    this.activo = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'activo': activo,
      };

  factory TipoConsulta.fromMap(Map<String, dynamic> map) => TipoConsulta(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        activo: map['activo'] as bool? ?? true,
      );

  TipoConsulta copyWith({
    String? id,
    String? nombre,
    bool? activo,
  }) {
    return TipoConsulta(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      activo: activo ?? this.activo,
    );
  }
}
