class Sede {
  final String id;
  final String nombre;
  final String direccion;
  final String? telefono;
  final bool activa;
  final String icono;

  Sede({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.telefono,
    this.activa = true,
    this.icono = 'store',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'nombre': nombre,
        'direccion': direccion,
        'telefono': telefono,
        'activa': activa,
        'icono': icono,
      };

  factory Sede.fromMap(Map<String, dynamic> map) => Sede(
        id: map['id'] as String,
        nombre: map['nombre'] as String,
        direccion: map['direccion'] as String,
        telefono: map['telefono'] as String?,
        activa: map['activa'] as bool? ?? true,
        icono: map['icono'] as String? ?? 'store',
      );

  Sede copyWith({
    String? id,
    String? nombre,
    String? direccion,
    String? telefono,
    bool? activa,
    String? icono,
  }) {
    return Sede(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      direccion: direccion ?? this.direccion,
      telefono: telefono ?? this.telefono,
      activa: activa ?? this.activa,
      icono: icono ?? this.icono,
    );
  }
}
