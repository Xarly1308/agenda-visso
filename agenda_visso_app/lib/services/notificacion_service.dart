import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colombian_holidays.dart';
import '../utils/formato_hora.dart';
import '../models/cita.dart';
import '../models/notificacion.dart';
import '../services/firestore_rest_service.dart';

class NotificacionService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final FirestoreRestService _rest = FirestoreRestService();
  static Timer? _pollTimer;
  static Map<String, String> _conocidas = {};

  static Future<void> init() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();

    final token = await messaging.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final snackBar = SnackBar(
      content: Text(message.notification?.body ?? 'Nueva notificación'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    );
    messengerKey.currentState?.showSnackBar(snackBar);
  }

  static Stream<List<Cita>> citasStream(String profesionalId) {
    _conocidas = {};
    final desde = DateTime.now();
    final hasta = desde.add(const Duration(days: 30));

    return Stream.periodic(const Duration(seconds: 15), (_) => null).asyncMap(
      (_) async {
        try {
          return await _rest.pollCitasEnRango(
            profesionalId: profesionalId,
            desde: desde,
            hasta: hasta,
          );
        } catch (_) {
          return <Cita>[];
        }
      },
    );
  }

  static void monitorearCitas({
    required BuildContext context,
    required String profesionalId,
  }) {
    _pollTimer?.cancel();
    _conocidas = {};
    final desde = DateTime.now();
    final hasta = desde.add(const Duration(days: 30));

    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        final citas = await _rest.pollCitasEnRango(
          profesionalId: profesionalId,
          desde: desde,
          hasta: hasta,
        );

        for (final cita in citas) {
          final key = cita.id;
          final estado = cita.estado;

          if (!_conocidas.containsKey(key)) {
            _conocidas[key] = estado;
            _onCitaAdded(cita, context, profesionalId);
          } else if (_conocidas[key] != estado) {
            _conocidas[key] = estado;
            _onCitaModified(cita, context, profesionalId);
          }
        }
      } catch (_) {}
    });
  }

  static void _onCitaAdded(
      Cita cita, BuildContext context, String profesionalId) async {
    final creadoPor = cita.creadoPor;
    if (creadoPor == profesionalId) return;

    final mensaje =
        'Nueva cita agendada: ${cita.fecha} a las ${formato12h(cita.hora)}';
    final tipo = 'nueva_cita';

    final existentes = await _rest.getNotificaciones(profesionalId);
    final yaExiste = existentes.any(
        (n) => n.citaId == cita.id && n.tipo == tipo);
    if (yaExiste) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.teal,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    await _rest.addNotificacion(
      Notificacion(
        id: '',
        profesionalId: profesionalId,
        citaId: cita.id,
        tipo: tipo,
        mensaje: mensaje,
        subtitulo: creadoPor != null ? 'Desde la app' : 'Desde la web',
      ),
    );
  }

  static void _onCitaModified(
      Cita cita, BuildContext context, String profesionalId) async {
    final estado = cita.estado;
    String mensaje;
    String tipo;

    if (estado == 'cancelada') {
      mensaje = 'Cita cancelada: ${cita.fecha} a las ${formato12h(cita.hora)}';
      tipo = 'cancelada';
    } else if (estado == 'confirmada') {
      mensaje = 'Cita confirmada: ${cita.fecha} a las ${formato12h(cita.hora)}';
      tipo = 'confirmada';
    } else {
      return;
    }

    final existentes = await _rest.getNotificaciones(profesionalId);
    final yaExiste = existentes.any(
        (n) => n.citaId == cita.id && n.tipo == tipo);
    if (yaExiste) return;

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          behavior: SnackBarBehavior.floating,
          backgroundColor: estado == 'cancelada' ? Colors.red : Colors.teal,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    await _rest.addNotificacion(
      Notificacion(
        id: '',
        profesionalId: profesionalId,
        citaId: cita.id,
        tipo: tipo,
        mensaje: mensaje,
        subtitulo: 'Desde la web',
      ),
    );
  }

  static void detenerMonitoreo() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _conocidas = {};
  }

  static Future<List<DateTime>> proximosFestivos() async {
    final hoy = DateTime.now();
    final hasta = hoy.add(const Duration(days: 60));
    final festivos = ColombianHolidays.getHolidaysInRange(hoy, hasta);
    festivos.removeWhere((f) => f.isBefore(hoy));
    festivos.sort();
    return festivos;
  }
}
