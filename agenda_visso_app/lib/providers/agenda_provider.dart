import 'dart:async';
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
  Timer? _pollTimer;

  List<Cita> get citasDelDia => _citasDelDia;
  List<String> get slotsDisponibles => _slotsDisponibles;
  bool get cargando => _cargando;
  DateTime get fechaSeleccionada => _fechaSeleccionada;

  void inicializar(String profesionalId) {
    _profesionalId = profesionalId;
    cargarCitas(_fechaSeleccionada);
    _iniciarPolling();
  }

  void _iniciarPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      cargarCitas(_fechaSeleccionada);
    });
  }

  void detenerPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  void setFecha(DateTime fecha) {
    _fechaSeleccionada = fecha;
    cargarCitas(fecha);
  }

  Future<void> cargarCitas(DateTime fecha) async {
    _cargando = true;
    notifyListeners();
    try {
      final citas = await _service.getCitasPorFecha(fecha).timeout(const Duration(seconds: 10));
      if (_fechaSeleccionada == fecha) {
        _citasDelDia = citas;
      }
    } catch (_) {
      if (_fechaSeleccionada == fecha) {
        _citasDelDia = [];
      }
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> calcularSlots({
    required List<Horario> horariosDelDia,
    DateTime? fecha,
  }) async {
    _slotsDisponibles = CalculadorSlots.calcular(
      horariosDelDia: horariosDelDia,
      citasDelDia: _citasDelDia,
      fecha: fecha,
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

  Future<void> cambiarFechaHora(String citaId, DateTime fecha, String hora) async {
    final fechaStr = fecha.toIso8601String().split('T')[0];
    await _service.updateCitaFechaHora(citaId, fechaStr, hora);
    await cargarCitas(_fechaSeleccionada);
  }

  Future<void> eliminarCita(String citaId) async {
    await _service.deleteCita(citaId);
    await cargarCitas(_fechaSeleccionada);
  }

  @override
  void dispose() {
    detenerPolling();
    super.dispose();
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

  Future<void> borrarTodaLaAgenda() async {
    await _service.deleteAllCitas();
    _citasDelDia = [];
    notifyListeners();
  }

  Future<void> borrarTodaLaBaseDeDatos() async {
    await _service.deleteAllCollections();
    _citasDelDia = [];
    notifyListeners();
  }

  Future<void> limpiarDatos(List<String> collections) async {
    await _service.deleteSelectedCollections(collections);
    if (collections.contains('citas')) {
      _citasDelDia = [];
    }
    notifyListeners();
  }
}
