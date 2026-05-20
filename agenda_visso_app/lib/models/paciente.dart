class Paciente {
  final String id;
  final String documento;
  final String nombres;
  final String telefono;
  final String? email;
  final bool yaEraPaciente;
  final DateTime creadoEn;

  Paciente({
    required this.id,
    required this.documento,
    required this.nombres,
    required this.telefono,
    this.email,
    this.yaEraPaciente = false,
    DateTime? creadoEn,
  }) : creadoEn = creadoEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'documento': documento,
        'nombres': nombres,
        'telefono': telefono,
        'email': email,
        'yaEraPaciente': yaEraPaciente,
        'creadoEn': creadoEn.toIso8601String(),
      };

  factory Paciente.fromMap(Map<String, dynamic> map) => Paciente(
        id: map['id'] as String,
        documento: map['documento'] as String,
        nombres: map['nombres'] as String,
        telefono: map['telefono'] as String,
        email: map['email'] as String?,
        yaEraPaciente: map['yaEraPaciente'] as bool? ?? false,
        creadoEn: DateTime.parse(map['creadoEn'] as String),
      );

  Paciente copyWith({
    String? id,
    String? documento,
    String? nombres,
    String? telefono,
    String? email,
    bool? yaEraPaciente,
    DateTime? creadoEn,
  }) {
    return Paciente(
      id: id ?? this.id,
      documento: documento ?? this.documento,
      nombres: nombres ?? this.nombres,
      telefono: telefono ?? this.telefono,
      email: email ?? this.email,
      yaEraPaciente: yaEraPaciente ?? this.yaEraPaciente,
      creadoEn: creadoEn ?? this.creadoEn,
    );
  }
}
