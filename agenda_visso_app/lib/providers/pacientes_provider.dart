import 'package:flutter/foundation.dart';
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

  List<Paciente> get resultados => _resultados;
  bool get cargando => _cargando;
  SortMode get sortMode => _sortMode;

  Future<void> cargarTodos() async {
    _cargando = true;
    notifyListeners();
    _todos = await _service.getAllPacientes();
    _aplicarFiltros();
    _cargando = false;
    notifyListeners();
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
