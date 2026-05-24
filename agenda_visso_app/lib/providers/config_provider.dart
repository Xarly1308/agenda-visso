import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../models/excepcion.dart';
import '../services/firestore_service.dart';
import '../utils/calculador_slots.dart';

class ConfigProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Sede> _sedes = [];
  List<Horario> _horarios = [];
  bool _cargando = false;
  String? _profesionalId;
  String? _sedeSeleccionadaId;

  List<Sede> get sedes => _sedes;
  List<Horario> get horarios => _horarios;
  bool get cargando => _cargando;
  String? get sedeSeleccionadaId => _sedeSeleccionadaId;

  Sede? get sedeSeleccionada {
    if (_sedeSeleccionadaId == null) return null;
    return _sedes.where((s) => s.id == _sedeSeleccionadaId).firstOrNull;
  }

  void inicializar(String profesionalId) {
    _profesionalId = profesionalId;
    cargarSedes();
  }

  Future<void> cargarSedes() async {
    _cargando = true;
    notifyListeners();
    try {
      _sedes = await _service.getSedes();
      if (_profesionalId != null) {
        _horarios = await _service.getHorariosPorProfesional(_profesionalId!);
      }
    } catch (e) {
      debugPrint('cargarSedes error: $e');
      _sedes = [];
      _horarios = [];
    }
    await _restaurarSede();
    _cargando = false;
    notifyListeners();
  }

  Future<void> _restaurarSede() async {
    if (_sedes.isEmpty) {
      _sedeSeleccionadaId = null;
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString('sede_default');
    if (savedId != null && _sedes.any((s) => s.id == savedId)) {
      _sedeSeleccionadaId = savedId;
    } else {
      _sedeSeleccionadaId = _sedes.first.id;
    }
  }

  Future<void> setSedeSeleccionada(String sedeId) async {
    _sedeSeleccionadaId = sedeId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('sede_default', sedeId);
    notifyListeners();
  }

  void popularSedes(List<Sede> sedes, String sedeId) {
    _sedes = List.from(sedes); // ensure a new list
    _sedeSeleccionadaId = sedeId;
    notifyListeners();
  }

  bool get necesitaSeleccionarSede => _sedes.isNotEmpty && _sedeSeleccionadaId == null;

  Future<void> agregarSede(Sede sede) async {
    await _service.addSede(sede);
    await cargarSedes();
  }

  Future<void> actualizarSede(Sede sede) async {
    await _service.updateSede(sede);
    await cargarSedes();
  }

  Future<void> eliminarSede(String id) async {
    await _service.deleteSede(id);
    await cargarSedes();
    if (_sedeSeleccionadaId == id) _sedeSeleccionadaId = null;
  }

  List<Horario> getHorariosPorSede(String sedeId) {
    return _horarios.where((h) => h.sedeId == sedeId).toList();
  }

  List<int> diasLaboralesEnSede(String sedeId) {
    return CalculadorSlots.diasLaborales(
      horariosDelProfesional: _horarios,
      sedeId: sedeId,
    );
  }

  List<Horario> getHorariosPorDia(String sedeId, int diaSemana) {
    return _horarios
        .where((h) => h.sedeId == sedeId && h.diaSemana == diaSemana)
        .toList();
  }

  Future<void> guardarHorarios({
    required String sedeId,
    required List<Horario> horarios,
  }) async {
    if (_profesionalId == null) return;
    await _service.setHorarios(
      profesionalId: _profesionalId!,
      sedeId: sedeId,
      horarios: horarios,
    );
    await cargarSedes();
  }

  Future<List<Excepcion>> cargarExcepciones() async {
    if (_profesionalId == null) return [];
    return await _service.getExcepciones(_profesionalId!);
  }

  Future<void> agregarExcepcion({
    required DateTime fecha,
    required String motivo,
  }) async {
    if (_profesionalId == null) return;
    await _service.addExcepcion(Excepcion(
      id: '',
      profesionalId: _profesionalId!,
      fecha: fecha,
      motivo: motivo,
    ));
  }

  Future<void> eliminarExcepcion(String fechaStr) async {
    if (_profesionalId == null) return;
    final excepciones = await _service.getExcepciones(_profesionalId!);
    final match = excepciones.where((e) =>
        e.fecha.toIso8601String().split('T')[0] == fechaStr);
    for (final e in match) {
      await _service.deleteExcepcion(e.id);
    }
  }
}
