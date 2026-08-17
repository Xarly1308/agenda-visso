import 'package:flutter/foundation.dart';
import '../models/cita.dart';
import '../models/paciente.dart';
import '../services/firestore_service.dart';

enum SortMode { masReciente, masAntiguo, alfabeticoAZ, alfabeticoZA }

class PacientesProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Paciente> _todos = [];
  List<Paciente> _resultados = [];
  bool _cargando = true;
  String _query = '';
  SortMode _sortMode = SortMode.masReciente;
  Map<String, Cita> _ultimasCitas = {};

  List<Paciente> get resultados => _resultados;
  List<Paciente> get todos => _todos;
  bool get cargando => _cargando;
  SortMode get sortMode => _sortMode;
  Map<String, Cita> get ultimasCitas => _ultimasCitas;

  Cita? getUltimaCita(String pacienteId) => _ultimasCitas[pacienteId];

  Future<void> cargarTodos() async {
    _cargando = true;
    notifyListeners();
    _todos = await _service.getAllPacientes();
    _aplicarFiltros();
    await _cargarUltimasCitas();
    _cargando = false;
    notifyListeners();
  }

  Future<void> _cargarUltimasCitas() async {
    try {
      final ahora = DateTime.now();
      final inicio = ahora.subtract(const Duration(days: 365));
      final todasLasCitas = await _service.getCitasEnRango(inicio, ahora);
      final mapa = <String, Cita>{};
      for (final cita in todasLasCitas) {
        final existente = mapa[cita.pacienteId];
        if (existente == null || cita.fecha.isAfter(existente.fecha) ||
            (cita.fecha.isAtSameMomentAs(existente.fecha) && cita.hora.compareTo(existente.hora) > 0)) {
          mapa[cita.pacienteId] = cita;
        }
      }
      _ultimasCitas = mapa;
    } catch (_) {
      _ultimasCitas = {};
    }
  }

  void buscar(String query) {
    _query = query.trim().toLowerCase();
    _aplicarFiltros();
  }

  void cambiarSortMode(SortMode mode) {
    _sortMode = mode;
    _aplicarFiltros();
  }

  void _aplicarFiltros() {
    var lista = _todos;

    if (_query.isNotEmpty) {
      lista = lista.where((p) =>
          p.nombres.toLowerCase().contains(_query) ||
          p.documento.toLowerCase().contains(_query)
      ).toList();
    }

    switch (_sortMode) {
      case SortMode.masReciente:
        lista.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
        break;
      case SortMode.masAntiguo:
        lista.sort((a, b) => a.creadoEn.compareTo(b.creadoEn));
        break;
      case SortMode.alfabeticoAZ:
        lista.sort((a, b) => a.nombres.toLowerCase().compareTo(b.nombres.toLowerCase()));
        break;
      case SortMode.alfabeticoZA:
        lista.sort((a, b) => b.nombres.toLowerCase().compareTo(a.nombres.toLowerCase()));
        break;
    }

    _resultados = lista;
    notifyListeners();
  }
}
