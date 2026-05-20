import 'package:flutter_test/flutter_test.dart';
import 'package:agenda_visso_app/utils/calculador_slots.dart';
import 'package:agenda_visso_app/models/horario.dart';
import 'package:agenda_visso_app/models/cita.dart';
import 'package:agenda_visso_app/models/excepcion.dart';

void main() {
  group('CalculadorSlots.calcular', () {
    test('genera slots de 30 min en rango simple', () {
      final horarios = [
        Horario(
          id: '1',
          profesionalId: 'p1',
          sedeId: 's1',
          diaSemana: 1,
          horaInicio: '08:00',
          horaFin: '10:00',
        ),
      ];

      final slots =
          CalculadorSlots.calcular(horariosDelDia: horarios, citasDelDia: []);

      expect(slots, ['08:00', '08:30', '09:00', '09:30']);
    });

    test('excluye slots ocupados pero no los cancelados', () {
      final horarios = [
        Horario(
          id: '1',
          profesionalId: 'p1',
          sedeId: 's1',
          diaSemana: 1,
          horaInicio: '08:00',
          horaFin: '10:00',
        ),
      ];
      final citas = [
        Cita(
          id: 'c1',
          profesionalId: 'p1',
          sedeId: 's1',
          pacienteId: 'pac1',
          fecha: DateTime(2026, 5, 18),
          hora: '08:30',
        ),
        Cita(
          id: 'c2',
          profesionalId: 'p1',
          sedeId: 's1',
          pacienteId: 'pac2',
          fecha: DateTime(2026, 5, 18),
          hora: '09:30',
          estado: 'cancelada',
        ),
      ];

      final slots =
          CalculadorSlots.calcular(horariosDelDia: horarios, citasDelDia: citas);

      expect(slots, ['08:00', '09:00', '09:30']);
    });

    test('genera slots con rango partido (mañana + tarde)', () {
      final horarios = [
        Horario(
          id: '1',
          profesionalId: 'p1',
          sedeId: 's1',
          diaSemana: 1,
          horaInicio: '08:00',
          horaFin: '12:00',
        ),
        Horario(
          id: '2',
          profesionalId: 'p1',
          sedeId: 's1',
          diaSemana: 1,
          horaInicio: '14:00',
          horaFin: '18:00',
        ),
      ];

      final slots =
          CalculadorSlots.calcular(horariosDelDia: horarios, citasDelDia: []);

      expect(slots.length, 16);
      expect(slots.first, '08:00');
      expect(slots.last, '17:30');
      expect(slots.contains('12:30'), false);
    });

    test('retorna lista vacía si todo está ocupado', () {
      final horarios = [
        Horario(
          id: '1',
          profesionalId: 'p1',
          sedeId: 's1',
          diaSemana: 1,
          horaInicio: '08:00',
          horaFin: '09:00',
        ),
      ];
      final citas = [
        Cita(
          id: 'c1',
          profesionalId: 'p1',
          sedeId: 's1',
          pacienteId: 'pac1',
          fecha: DateTime(2026, 5, 18),
          hora: '08:00',
        ),
        Cita(
          id: 'c2',
          profesionalId: 'p1',
          sedeId: 's1',
          pacienteId: 'pac2',
          fecha: DateTime(2026, 5, 18),
          hora: '08:30',
        ),
      ];

      final slots =
          CalculadorSlots.calcular(horariosDelDia: horarios, citasDelDia: citas);

      expect(slots, isEmpty);
    });

    test('retorna lista vacía si no hay horarios para ese día', () {
      final slots =
          CalculadorSlots.calcular(horariosDelDia: [], citasDelDia: []);

      expect(slots, isEmpty);
    });
  });

  group('CalculadorSlots.diasLaborales', () {
    test('retorna días únicos ordenados para una sede', () {
      final horarios = [
        Horario(
            id: '1',
            profesionalId: 'p1',
            sedeId: 's1',
            diaSemana: 1,
            horaInicio: '08:00',
            horaFin: '12:00'),
        Horario(
            id: '2',
            profesionalId: 'p1',
            sedeId: 's1',
            diaSemana: 3,
            horaInicio: '08:00',
            horaFin: '12:00'),
        Horario(
            id: '3',
            profesionalId: 'p1',
            sedeId: 's1',
            diaSemana: 1,
            horaInicio: '14:00',
            horaFin: '18:00'),
        Horario(
            id: '4',
            profesionalId: 'p1',
            sedeId: 's2',
            diaSemana: 5,
            horaInicio: '08:00',
            horaFin: '12:00'),
      ];

      final dias = CalculadorSlots.diasLaborales(
          horariosDelProfesional: horarios, sedeId: 's1');

      expect(dias, [1, 3]);
    });

    test('retorna vacío si el profesional no atiende en esa sede', () {
      final horarios = [
        Horario(
            id: '1',
            profesionalId: 'p1',
            sedeId: 's1',
            diaSemana: 1,
            horaInicio: '08:00',
            horaFin: '12:00'),
      ];

      final dias = CalculadorSlots.diasLaborales(
          horariosDelProfesional: horarios, sedeId: 's2');

      expect(dias, isEmpty);
    });
  });

  group('CalculadorSlots.fechasDisponiblesEnRango', () {
    test('genera fechas según días laborales en un rango', () {
      final fechas = CalculadorSlots.fechasDisponiblesEnRango(
        desde: DateTime(2026, 5, 18),
        hasta: DateTime(2026, 5, 24),
        diasLaborales: [1, 3, 5],
        excepciones: [],
      );

      expect(fechas, [
        DateTime(2026, 5, 18), // lunes
        DateTime(2026, 5, 20), // miércoles
        DateTime(2026, 5, 22), // viernes
      ]);
    });

    test('excluye fechas con excepciones', () {
      final fechas = CalculadorSlots.fechasDisponiblesEnRango(
        desde: DateTime(2026, 5, 18),
        hasta: DateTime(2026, 5, 24),
        diasLaborales: [1, 3, 5],
        excepciones: [
          Excepcion(id: 'e1', profesionalId: 'p1', fecha: DateTime(2026, 5, 18), motivo: 'Festivo'),
        ],
      );

      expect(fechas, [
        DateTime(2026, 5, 20),
        DateTime(2026, 5, 22),
      ]);
    });

    test('retorna vacío si no hay días laborales en rango', () {
      final fechas = CalculadorSlots.fechasDisponiblesEnRango(
        desde: DateTime(2026, 5, 23),
        hasta: DateTime(2026, 5, 24),
        diasLaborales: [1, 3],
        excepciones: [],
      );

      expect(fechas, isEmpty);
    });
  });
}
