import 'package:flutter/material.dart';
import '../models/cita.dart';
import '../models/horario.dart';
import '../models/paciente.dart';
import '../models/notificacion.dart';
import '../services/firestore_service.dart';
import '../utils/calculador_slots.dart';
import '../utils/formato_hora.dart';

class AgendaProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Cita> _citasDelDia = [];
  List<String> _slotsDisponibles = [];
  bool _cargando = false;
  DateTime _fechaSeleccionada = DateTime.now();
  String? _profesionalId;

  List<Cita> get citasDelDia => _citasDelDia;
  List<String> get slotsDisponibles => _slotsDisponibles;
  bool get cargando => _cargando;
  DateTime get fechaSeleccionada => _fechaSeleccionada;

  void inicializar(String profesionalId) {
    _profesionalId = profesionalId;
    cargarCitas(_fechaSeleccionada);
  }

  void setFecha(DateTime fecha) {
    _fechaSeleccionada = fecha;
    cargarCitas(fecha);
  }

  Future<void> cargarCitas(DateTime fecha) async {
    _cargando = true;
    notifyListeners();

    final citas = await _service.getCitasPorFecha(fecha);
    _citasDelDia = citas;

    _cargando = false;
    notifyListeners();
  }

  Future<void> calcularSlots({
    required List<Horario> horariosDelDia,
  }) async {
    _slotsDisponibles = CalculadorSlots.calcular(
      horariosDelDia: horariosDelDia,
      citasDelDia: _citasDelDia,
    );
    notifyListeners();
  }

  Future<Cita?> agendarCita({
    required String sedeId,
    required String pacienteId,
    required DateTime fecha,
    required String hora,
    String? mensaje,
    String? creadoPor,
    String? pacienteNombre,
    String? tipoConsulta,
  }) async {
    if (_profesionalId == null) return null;

    final cita = Cita(
      id: '',
      profesionalId: _profesionalId!,
      sedeId: sedeId,
      pacienteId: pacienteId,
      fecha: fecha,
      hora: hora,
      mensajePersonalizado: mensaje,
      creadoPor: creadoPor,
      pacienteNombre: pacienteNombre,
      tipoConsulta: tipoConsulta,
    );

    final creada = await _service.addCita(cita);
    setFecha(fecha);
    return creada;
  }

  Future<void> cambiarEstadoCita(String citaId, String nuevoEstado) async {
    final cita = _citasDelDia.firstWhere((c) => c.id == citaId);
    await _service.updateCitaEstado(citaId, nuevoEstado);
    if (nuevoEstado == 'cancelada') {
      final fechaStr =
          '${cita.fecha.day}/${cita.fecha.month}/${cita.fecha.year}';
      try {
        final profesionales = await _service.getProfesionales();
        for (final p in profesionales) {
          if (p['id'] == _profesionalId) continue;
          await _service.addNotificacion(
            Notificacion(
              id: '',
              profesionalId: p['id'] as String,
              citaId: citaId,
              tipo: 'cancelada',
              mensaje: 'Cita cancelada del $fechaStr a las ${formato12h(cita.hora)}',
              subtitulo: 'Cancelado por un profesional',
            ),
          );
        }
      } catch (_) {}
    }
    await cargarCitas(_fechaSeleccionada);
  }

  Future<void> eliminarCita(String citaId) async {
    await _service.deleteCita(citaId);
    await cargarCitas(_fechaSeleccionada);
  }

  Future<void> limpiarSemana() async {
    if (_profesionalId == null) return;
    final hoy = DateTime.now();
    final inicioSemana = hoy.subtract(Duration(days: hoy.weekday - 1));
    final finSemana = inicioSemana.add(const Duration(days: 6));
    await _service.deleteCitasEnRango(_profesionalId!, inicioSemana, finSemana);
    await cargarCitas(_fechaSeleccionada);
  }

  Future<void> limpiarAntiguas() async {
    if (_profesionalId == null) return;
    final hoy = DateTime.now();
    final inicio = DateTime(2020, 1, 1);
    final ayer = hoy.subtract(const Duration(days: 1));
    await _service.deleteCitasEnRango(_profesionalId!, inicio, ayer);
    await cargarCitas(_fechaSeleccionada);
  }

  Future<Paciente?> buscarOPacientePorDocumento(String documento) async {
    return await _service.getPacientePorDocumento(documento);
  }

  Future<Paciente> registrarPaciente(Paciente paciente) async {
    return await _service.addPaciente(paciente);
  }
}
