class Paciente {
  final String id;
  final String documento;
  final String nombres;
  final String telefono;
  final String? email;
  final String? fotoUrl;
  final bool yaEraPaciente;
  final DateTime creadoEn;

  Paciente({
    required this.id,
    required this.documento,
    required this.nombres,
    required this.telefono,
    this.email,
    this.fotoUrl,
    this.yaEraPaciente = false,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'documento': documento,
        'nombres': nombres,
        'telefono': telefono,
        'email': email,
        'fotoUrl': fotoUrl,
        'yaEraPaciente': yaEraPaciente,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory Paciente.fromMap(Map<String, dynamic> map) => Paciente(
        id: map['id'] as String? ?? '',
        documento: map['documento'] as String? ?? '',
        nombres: map['nombres'] as String? ?? '',
        telefono: map['telefono'] as String? ?? '',
        email: map['email'] as String?,
        fotoUrl: map['fotoUrl'] as String?,
        yaEraPaciente: map['yaEraPaciente'] as bool? ?? false,
        creadoEn: DateTime.tryParse(map['creadoEn'] as String? ?? '') ?? DateTime.now(),
      );

  Paciente copyWith({
    String? id,
    String? documento,
    String? nombres,
    String? telefono,
    String? email,
    String? fotoUrl,
    bool? yaEraPaciente,
    DateTime? creadoEn,
  }) {
    return Paciente(
      id: id ?? this.id,
      documento: documento ?? this.documento,
      nombres: nombres ?? this.nombres,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      yaEraPaciente: yaEraPaciente ?? this.yaEraPaciente,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
