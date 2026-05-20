import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../services/firestore_service.dart';

class NotificacionProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Notificacion> _notificaciones = [];
  int _noLeidas = 0;
  bool _cargando = false;
  String? _profesionalId;

  List<Notificacion> get notificaciones => _notificaciones;
  int get noLeidas => _noLeidas;
  bool get cargando => _cargando;

  void inicializar(String profesionalId) {
    _profesionalId = profesionalId;
    cargar();
  }

  Future<void> cargar() async {
    if (_profesionalId == null) return;
    _cargando = true;
    notifyListeners();

    _notificaciones = await _service.getNotificaciones(_profesionalId!);
    _noLeidas = _notificaciones.where((n) => !n.leida).length;

    _cargando = false;
    notifyListeners();
  }

  Future<void> marcarLeidas() async {
    if (_profesionalId == null) return;
    await _service.marcarNotificacionesLeidas(_profesionalId!);
    _noLeidas = 0;
    _notificaciones = _notificaciones.map((n) => n.copyWith(leida: true)).toList();
    notifyListeners();
  }
}
