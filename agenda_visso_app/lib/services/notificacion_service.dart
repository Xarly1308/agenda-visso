import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colombian_holidays.dart';
import '../utils/formato_hora.dart';
import '../models/cita.dart';
import '../models/notificacion.dart';
import '../services/firestore_rest_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const android = AndroidInitializationSettings('@mipmap/ic_launcher');
  await plugin.initialize(const InitializationSettings(android: android));
  await plugin.show(
    0,
    message.notification?.title ?? 'Agenda Visso',
    message.notification?.body ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'nuevas_citas',
        'Nuevas citas',
        channelDescription: 'Notificaciones de nuevas citas agendadas',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
  );
}

class NotificacionService {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  static final FirestoreRestService _rest = FirestoreRestService();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static Timer? _pollTimer;
  static Map<String, String> _conocidas = {};

  static Future<void> init() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(const InitializationSettings(android: android));

    const channel = AndroidNotificationChannel(
      'nuevas_citas',
      'Nuevas citas',
      description: 'Notificaciones de nuevas citas agendadas',
      importance: Importance.high,
    );
    await _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    await messaging.subscribeToTopic('profesional_notificaciones');

    final token = await messaging.getToken();
    if (token != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);
    }

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
  }

  static void _onForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? 'Nueva notificación';
    final body = message.notification?.body ?? '';

    _localNotifications.show(
      0,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'nuevas_citas',
          'Nuevas citas',
          channelDescription: 'Notificaciones de nuevas citas agendadas',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );

    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
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

    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);

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
