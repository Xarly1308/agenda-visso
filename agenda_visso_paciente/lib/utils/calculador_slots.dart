import '../models/horario.dart';
import '../models/cita.dart';
import '../models/excepcion.dart';

class CalculadorSlots {
  static const int duracionSlotMinutos = 30;

  static List<String> calcular({
    required List<Horario> horariosDelDia,
    required List<Cita> citasDelDia,
    DateTime? fecha,
  }) {
    final ocupados = citasDelDia
        .where((c) => c.estado != 'cancelada')
        .map((c) => c.hora)
        .toSet();

    final slots = <String>{};
    final esHoy = fecha != null && _esMismoDia(fecha, DateTime.now());
    final ahoraMinutos = DateTime.now().hour * 60 + DateTime.now().minute;

    for (final horario in horariosDelDia) {
      final inicio = _horaToMinutos(horario.horaInicio);
      final fin = _horaToMinutos(horario.horaFin);

      for (int m = inicio; m < fin; m += duracionSlotMinutos) {
        if (esHoy && m <= ahoraMinutos) continue;
        final hora = _minutosToHora(m);
        slots.add(hora);
      }
    }

    slots.removeAll(ocupados);

    final resultado = slots.toList();
    resultado.sort();
    return resultado;
  }

  static bool _esMismoDia(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static int _horaToMinutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  static String _minutosToHora(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static List<int> diasLaborales({
    required List<Horario> horariosDelProfesional,
    required String sedeId,
  }) {
    return horariosDelProfesional
        .where((h) => h.sedeId == sedeId)
        .map((h) => h.diaSemana)
        .toSet()
        .toList()
      ..sort();
  }

  static List<DateTime> fechasDisponiblesEnRango({
    required DateTime desde,
    required DateTime hasta,
    required List<int> diasLaborales,
    required List<Excepcion> excepciones,
  }) {
    final fechasExcluidas =
        excepciones.map((e) => e.fecha.toIso8601String().split('T')[0]).toSet();
    final resultados = <DateTime>[];
    var actual = desde;

    while (!actual.isAfter(hasta)) {
      final fechaStr = actual.toIso8601String().split('T')[0];
      if (diasLaborales.contains(actual.weekday) && !fechasExcluidas.contains(fechaStr)) {
        resultados.add(actual);
      }
      actual = actual.add(const Duration(days: 1));
    }

    return resultados;
  }
}
