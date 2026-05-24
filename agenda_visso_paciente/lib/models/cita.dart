class Cita {
  final String id;
  final String profesionalId;
  final String sedeId;
  final String pacienteId;
  final DateTime fecha;
  final String hora;
  final String estado;
  final String? mensajePersonalizado;
  final bool notificada;
  final DateTime creadaEn;
  final String? creadoPor;
  final String? pacienteNombre;
  final String? tipoConsulta;

  Cita({
    required this.id,
    required this.profesionalId,
    required this.sedeId,
    required this.pacienteId,
    required this.fecha,
    required this.hora,
    this.estado = 'pendiente',
    this.mensajePersonalizado,
    this.notificada = false,
    DateTime? creadaEn,
    this.creadoPor,
    this.pacienteNombre,
    this.tipoConsulta,
  }) : creadaEn = creadaEn ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'profesionalId': profesionalId,
        'sedeId': sedeId,
        'pacienteId': pacienteId,
        'fecha': fecha.toIso8601String().split('T')[0],
        'hora': hora,
        'estado': estado,
        'mensajePersonalizado': mensajePersonalizado,
        'notificada': notificada,
        'creadaEn': creadaEn.toIso8601String(),
        'creadoPor': creadoPor,
        'pacienteNombre': pacienteNombre,
        'tipoConsulta': tipoConsulta,
      };

  factory Cita.fromMap(Map<String, dynamic> map) => Cita(
        id: map['id'] as String? ?? '',
        profesionalId: map['profesionalId'] as String? ?? '',
        sedeId: map['sedeId'] as String? ?? '',
        pacienteId: map['pacienteId'] as String? ?? '',
        fecha: DateTime.tryParse(map['fecha'] as String? ?? '') ?? DateTime.now(),
        hora: map['hora'] as String? ?? '00:00',
        estado: map['estado'] as String? ?? 'pendiente',
        mensajePersonalizado: map['mensajePersonalizado'] as String?,
        notificada: map['notificada'] as bool? ?? false,
        creadaEn: DateTime.tryParse(map['creadaEn'] as String? ?? '') ?? DateTime.now(),
        creadoPor: map['creadoPor'] as String?,
        pacienteNombre: map['pacienteNombre'] as String?,
        tipoConsulta: map['tipoConsulta'] as String?,
      );

  Cita copyWith({
    String? id,
    String? profesionalId,
    String? sedeId,
    String? pacienteId,
    DateTime? fecha,
    String? hora,
    String? estado,
    String? mensajePersonalizado,
    bool? notificada,
    DateTime? creadaEn,
    String? creadoPor,
    String? pacienteNombre,
    String? tipoConsulta,
  }) {
    return Cita(
      id: id ?? this.id,
      profesionalId: profesionalId ?? this.profesionalId,
      sedeId: sedeId ?? this.sedeId,
      pacienteId: pacienteId ?? this.pacienteId,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      estado: estado ?? this.estado,
      mensajePersonalizado: mensajePersonalizado ?? this.mensajePersonalizado,
      notificada: notificada ?? this.notificada,
      creadaEn: creadaEn ?? this.creadaEn,
      creadoPor: creadoPor ?? this.creadoPor,
      pacienteNombre: pacienteNombre ?? this.pacienteNombre,
      tipoConsulta: tipoConsulta ?? this.tipoConsulta,
    );
  }
}
