class Horario {
  final String id;
  final String profesionalId;
  final String sedeId;
  final int diaSemana;
  final String horaInicio;
  final String horaFin;

  Horario({
    required this.id,
    required this.profesionalId,
    required this.sedeId,
    required this.diaSemana,
    required this.horaInicio,
    required this.horaFin,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'profesionalId': profesionalId,
        'sedeId': sedeId,
        'diaSemana': diaSemana,
        'horaInicio': horaInicio,
        'horaFin': horaFin,
      };

  factory Horario.fromMap(Map<String, dynamic> map) => Horario(
        id: map['id'] as String,
        profesionalId: map['profesionalId'] as String,
        sedeId: map['sedeId'] as String,
        diaSemana: map['diaSemana'] as int,
        horaInicio: map['horaInicio'] as String,
        horaFin: map['horaFin'] as String,
      );

  Horario copyWith({
    String? id,
    String? profesionalId,
    String? sedeId,
    int? diaSemana,
    String? horaInicio,
    String? horaFin,
  }) {
    return Horario(
      id: id ?? this.id,
      profesionalId: profesionalId ?? this.profesionalId,
      sedeId: sedeId ?? this.sedeId,
      diaSemana: diaSemana ?? this.diaSemana,
      horaInicio: horaInicio ?? this.horaInicio,
      horaFin: horaFin ?? this.horaFin,
    );
  }
}
