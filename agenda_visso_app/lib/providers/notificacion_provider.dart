import 'dart:async';
import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../services/firestore_service.dart';

class NotificacionProvider extends ChangeNotifier {
  final FirestoreService _service = FirestoreService();
  List<Notificacion> _notificaciones = [];
  int _noLeidas = 0;
  bool _cargando = false;
  String? _profesionalId;
  Timer? _timer;

  List<Notificacion> get notificaciones => _notificaciones;
  int get noLeidas => _noLeidas;
  bool get cargando => _cargando;

  void inicializar(String profesionalId) {
    _profesionalId = profesionalId;
    cargar();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => cargar());
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> cargar() async {
    if (_profesionalId == null) return;
    _cargando = true;

    try {
      _notificaciones = await _service.getNotificaciones(_profesionalId!);
      _noLeidas = _notificaciones.where((n) => !n.leida).length;
    } catch (_) {
      _notificaciones = [];
      _noLeidas = 0;
    }

    _cargando = false;
    notifyListeners();
  }

  Future<void> marcarLeidas() async {
    if (_profesionalId == null) return;
    try {
      await _service.marcarNotificacionesLeidas(_profesionalId!);
    } catch (_) {}
    _noLeidas = 0;
    _notificaciones = _notificaciones.map((n) => n.copyWith(leida: true)).toList();
    notifyListeners();
  }

  @override
  void dispose() {
    detener();
    super.dispose();
  }
}
