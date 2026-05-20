import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../models/cita.dart';
import '../providers/agenda_provider.dart';
import '../providers/config_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notificacion_provider.dart';
import '../services/notificacion_service.dart';
import '../services/firestore_service.dart';
import '../services/app_update_service.dart';
import '../utils/colombian_holidays.dart';
import '../utils/formato_hora.dart';
import '../widgets/calendar_header.dart';
import 'nueva_cita_screen.dart';
import 'pacientes_screen.dart';
import 'config_screen.dart';
import 'estadisticas_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  bool _inicializado = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _inicializar());
  }

  void _inicializar() {
    if (_inicializado) return;
    _inicializado = true;

    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;

    final config = context.read<ConfigProvider>();
    config.inicializar(uid);
    context.read<AgendaProvider>().inicializar(uid);
    context.read<NotificacionProvider>().inicializar(uid);

    config.addListener(_onConfigLoaded);
  }

  void _onConfigLoaded() {
    final config = context.read<ConfigProvider>();
    if (!config.cargando && config.necesitaSeleccionarSede) {
      config.removeListener(_onConfigLoaded);
      WidgetsBinding.instance.addPostFrameCallback((_) => _mostrarSelectorSede());
    } else if (!config.cargando && config.sedeSeleccionadaId != null) {
      config.removeListener(_onConfigLoaded);
      _iniciarMonitoreo();
    }
  }

  void _iniciarMonitoreo() {
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    NotificacionService.monitorearCitas(context: context, profesionalId: uid);
    _mostrarFestivosProximos();
    _verificarActualizacion();
  }

  Future<void> _verificarActualizacion() async {
    try {
      final version = await AppUpdateService().getLatestVersion();
      if (version == null || !mounted) return;
      final latestVersion = version['version'];
      final apkUrl = version['apkUrl'];
      final notas = version['notas'];
      if (latestVersion == null || apkUrl == null) return;
      const currentVersion = '1.0.0';
      if (!AppUpdateService().isUpdateAvailable(latestVersion, currentVersion)) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Actualización disponible'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Versión $latestVersion disponible'),
              if (notas != null) ...[
                const SizedBox(height: 8),
                Text(notas, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ahora no'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Descargar'),
              onPressed: () {
                Navigator.pop(ctx);
                AppUpdateService().downloadUpdate(apkUrl);
              },
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  void _mostrarFestivosProximos() {
    NotificacionService.proximosFestivos().then((festivos) {
      if (!mounted || festivos.isEmpty) return;
      final nombres = festivos.take(3).map((f) {
        final nom = ColombianHolidays.nombreFestivo(f);
        return '${f.day}/${f.month}: $nom';
      }).join('\n');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Próximos festivos:\n$nombres'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          backgroundColor: Colors.orange,
        ),
      );
    });
  }

  Future<void> _mostrarSelectorSede() async {
    final config = context.read<ConfigProvider>();
    final sede = await showDialog<Sede>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Selecciona tu sede'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: config.sedes.map((s) => ListTile(
            title: Text(s.nombre),
            subtitle: Text(s.direccion),
            leading: CircleAvatar(child: Icon(iconoDeSede(s.icono))),
            onTap: () => Navigator.pop(ctx, s),
          )).toList(),
        ),
      ),
    );
    if (sede != null) {
      await config.setSedeSeleccionada(sede.id);
      _iniciarMonitoreo();
    }
  }

IconData iconoDeSede(String icono) {
  switch (icono) {
    case 'store': return Icons.store;
    case 'medical_services': return Icons.medical_services;
    case 'visibility': return Icons.visibility;
    case 'local_hospital': return Icons.local_hospital;
    case 'home': return Icons.home;
    case 'business': return Icons.business;
    case 'location_city': return Icons.location_city;
    case 'apartment': return Icons.apartment;
    default: return Icons.store;
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 32,
          child: Image.asset('assets/visso_logo.png', fit: BoxFit.contain),
        ),
        actions: [
          _buildNotificacionesBoton(context),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: [
          NavigationDestination(icon: Icon(Icons.today), label: 'Agenda'),
          NavigationDestination(icon: Icon(Icons.people), label: 'Pacientes'),
          NavigationDestination(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 24),
            ),
            label: 'Nueva',
          ),
          NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Estadísticas'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Configurar'),
        ],
      ),
    );
  }

  Widget _buildNotificacionesBoton(BuildContext context) {
    final notif = context.watch<NotificacionProvider>();
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => _mostrarNotificaciones(context),
        ),
        if (notif.noLeidas > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '${notif.noLeidas}',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  void _mostrarNotificaciones(BuildContext context) {
    final notif = context.read<NotificacionProvider>();
    notif.marcarLeidas();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Notificaciones', style: Theme.of(context).textTheme.titleLarge),
          const Divider(),
          if (notif.notificaciones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('Sin notificaciones', style: TextStyle(color: Colors.grey))),
            )
          else
            ...notif.notificaciones.map((n) => ListTile(
              leading: CircleAvatar(
                backgroundColor: n.tipo == 'cancelada'
                    ? Colors.red.shade100
                    : Colors.teal.shade100,
                child: Icon(
                  n.tipo == 'cancelada' ? Icons.cancel : Icons.check_circle,
                  color: n.tipo == 'cancelada' ? Colors.red : Colors.teal,
                  size: 20,
                ),
              ),
              title: Text(n.mensaje, style: const TextStyle(fontSize: 14)),
              subtitle: Text(n.subtitulo, style: const TextStyle(fontSize: 12)),
            )),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return const _AgendaView();
      case 1:
        return const PacientesScreen();
      case 2:
        return NuevaCitaScreen(onCitaCreada: () {
          setState(() => _selectedIndex = 0);
        });
      case 3:
        return const EstadisticasScreen();
      case 4:
        return const _ConfigView();
      default:
        return const _AgendaView();
    }
  }
}

class _AgendaView extends StatefulWidget {
  const _AgendaView();

  @override
  State<_AgendaView> createState() => _AgendaViewState();
}

class _AgendaViewState extends State<_AgendaView> {
  final _service = FirestoreService();
  List<Horario> _horariosDelDia = [];
  DateTime? _ultimaFecha;
  String? _ultimaSede;
  Set<String> _excepcionFechas = {};
  Map<String, String> _excepcionMotivos = {};

  @override
  Widget build(BuildContext context) {
    final agenda = context.watch<AgendaProvider>();
    final config = context.watch<ConfigProvider>();
    final citas = agenda.citasDelDia;
    final fecha = agenda.fechaSeleccionada;
    final sedeId = config.sedeSeleccionadaId;
    final esFestivo = ColombianHolidays.esFestivo(fecha);
    final nombreFestivo = ColombianHolidays.nombreFestivo(fecha);

    if (fecha != _ultimaFecha || sedeId != _ultimaSede) {
      _ultimaFecha = fecha;
      _ultimaSede = sedeId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _cargarHorariosYExcepciones(fecha, sedeId);
      });
    }

    final citasSede = sedeId == null
        ? citas
        : citas.where((c) => c.sedeId == sedeId).toList();

    final timeline = _generarTimeline(citasSede);
    final fechaStr = '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    final motivoBloqueo = _excepcionMotivos[fechaStr];

    return Column(
      children: [
        if (esFestivo)
          Container(
            width: double.infinity,
            color: Colors.orange.shade100,
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.celebration, size: 16, color: Colors.orange),
                const SizedBox(width: 8),
                Text('Festivo: $nombreFestivo',
                    style: const TextStyle(fontSize: 13, color: Colors.orange)),
              ],
            ),
          ),
        _buildSedeSelector(config, agenda),
        CalendarHeader(
          selectedDate: fecha,
          excepcionFechas: _excepcionFechas,
          onDateSelected: (d) => agenda.setFecha(d),
          onDatePickerTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: fecha,
              firstDate: fecha.subtract(const Duration(days: 365)),
              lastDate: fecha.add(const Duration(days: 365)),
              locale: const Locale('es', 'ES'),
              initialEntryMode: DatePickerEntryMode.calendarOnly,
            );
            if (picked != null) agenda.setFecha(picked);
          },
        ),
        const Divider(height: 8),
        if (agenda.cargando)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (motivoBloqueo != null || timeline.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(motivoBloqueo != null ? Icons.block : Icons.event_busy,
                      size: 40, color: motivoBloqueo != null ? Colors.orange : Colors.grey),
                  const SizedBox(height: 8),
                  Text(
                    motivoBloqueo ?? 'No hay horarios para este día',
                    style: TextStyle(
                      color: motivoBloqueo != null ? Colors.orange.shade800 : Colors.grey,
                      fontWeight: motivoBloqueo != null ? FontWeight.w500 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (motivoBloqueo != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Día marcado como no laborable',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: timeline.length + (citasCanceladas(citasSede).isNotEmpty ? citasCanceladas(citasSede).length : 0),
              itemBuilder: (context, i) {
                if (i < timeline.length) {
                  return _buildTimelineRow(timeline[i]);
                }
                // Show canceled citas at the bottom
                final canceladas = citasCanceladas(citasSede);
                if (canceladas.isEmpty) return null; // shouldn't happen
                if (i == timeline.length) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text('Canceladas',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  );
                }
                final c = canceladas[i - timeline.length - 1];
                return _buildCitaCard(c, Colors.red.shade200);
              },
            ),
          ),
      ],
    );
  }

  List<Cita> citasCanceladas(List<Cita> citas) {
    return citas.where((c) => c.estado == 'cancelada').toList();
  }

  Future<void> _cargarHorariosYExcepciones(DateTime fecha, String? sedeId) async {
    if (sedeId == null) return;
    final auth = context.read<AuthProvider>();
    final uid = auth.user?.uid;
    if (uid == null) return;
    if (mounted) {
      setState(() {
        _horariosDelDia = [];
      });
    }
    final todos = await _service.getHorariosPorProfesional(uid);
    _horariosDelDia = todos.where((h) =>
        h.sedeId == sedeId && h.diaSemana == fecha.weekday).toList();
    final excepciones = await _service.getExcepciones(uid);
    _excepcionFechas = excepciones
        .map((e) => '${e.fecha.year}-${e.fecha.month.toString().padLeft(2, '0')}-${e.fecha.day.toString().padLeft(2, '0')}')
        .toSet();
    _excepcionMotivos = {};
    for (final e in excepciones) {
      final fs = '${e.fecha.year}-${e.fecha.month.toString().padLeft(2, '0')}-${e.fecha.day.toString().padLeft(2, '0')}';
      _excepcionMotivos[fs] = e.motivo;
    }
    if (mounted) setState(() {});
  }

  Widget _buildSedeSelector(ConfigProvider config, AgendaProvider agenda) {
    final sedes = config.sedes;
    if (sedes.isEmpty) return const SizedBox.shrink();
    final seleccionada = config.sedeSeleccionadaId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: sedes.map((s) {
            final activa = s.id == seleccionada;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: _SedeChip(
                icono: s.icono,
                nombre: s.nombre,
                activa: activa,
                onTap: () {
                  if (!activa) {
                    config.setSedeSeleccionada(s.id);
                    agenda.setFecha(DateTime.now());
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  List<_TimelineSlot> _generarTimeline(List<Cita> citas) {
    final slots = <_TimelineSlot>[];
    final ocupadas = citas
        .where((c) => c.estado != 'cancelada')
        .fold<Map<String, Cita>>({}, (map, c) {
      map[c.hora] = c;
      return map;
    });

    for (final h in _horariosDelDia) {
      final inicio = _horaToMinutos(h.horaInicio);
      final fin = _horaToMinutos(h.horaFin);
      if (inicio >= fin) continue;
      for (int m = inicio; m < fin; m += 30) {
        final hora = _minutosToHora(m);
        final esLabelHora = m % 60 == 0;
        slots.add(_TimelineSlot(
          hora: hora,
          cita: ocupadas[hora],
          esLabelHora: esLabelHora,
        ));
      }
    }
    return slots;
  }

  Widget _buildTimelineRow(_TimelineSlot slot) {
    final esPar = _horaToMinutos(slot.hora) ~/ 30 % 2 == 0;
    return Container(
      height: slot.cita != null ? 72 : 36,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        color: esPar ? Colors.transparent : Colors.grey.shade50,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Padding(
              padding: EdgeInsets.only(
                top: slot.esLabelHora ? 4 : (slot.cita != null ? 4 : 0),
                left: 8,
              ),
              child: Text(
                slot.esLabelHora ? formato12h(slot.hora) : '',
                style: TextStyle(
                  fontSize: slot.esLabelHora ? 12 : 10,
                  fontWeight: slot.esLabelHora ? FontWeight.w600 : FontWeight.w400,
                  color: slot.esLabelHora ? Colors.black87 : Colors.grey.shade400,
                ),
              ),
            ),
          ),
          VerticalDivider(width: 1, color: Colors.grey.shade300),
          Expanded(
            child: slot.cita != null
                ? _buildCitaCard(slot.cita!)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildCitaCard(Cita cita, [Color? colorEstado]) {
    final estado = cita.estado;
    final color = colorEstado ?? (estado == 'pendiente'
        ? Colors.orange
        : estado == 'confirmada'
            ? Colors.green
            : Colors.red);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withAlpha(80), width: 1.5),
        ),
        elevation: 0,
        color: color.withAlpha(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _mostrarMenuCita(context, cita),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cita.pacienteNombre ?? cita.pacienteId,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formato12h(cita.hora)} · ${_estadoLabel(estado)}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withAlpha(30),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _estadoLabel(estado),
                    style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.more_vert, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarMenuCita(BuildContext context, Cita cita) {
    final agenda = context.read<AgendaProvider>();
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                cita.pacienteNombre ?? cita.pacienteId,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            if (cita.estado != 'confirmada')
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: const Text('Confirmar'),
                onTap: () {
                  Navigator.pop(ctx);
                  agenda.cambiarEstadoCita(cita.id, 'confirmada');
                },
              ),
            if (cita.estado != 'cancelada')
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Cancelar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  agenda.cambiarEstadoCita(cita.id, 'cancelada');
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Eliminar', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                agenda.eliminarCita(cita.id);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _estadoLabel(String e) {
    switch (e) {
      case 'pendiente': return 'Pendiente';
      case 'confirmada': return 'Confirmada';
      case 'cancelada': return 'Cancelada';
      default: return e;
    }
  }

  int _horaToMinutos(String hora) {
    final partes = hora.split(':');
    return int.parse(partes[0]) * 60 + int.parse(partes[1]);
  }

  String _minutosToHora(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}

class _TimelineSlot {
  final String hora;
  final Cita? cita;
  final bool esLabelHora;
  _TimelineSlot({
    required this.hora,
    this.cita,
    required this.esLabelHora,
  });
}

class _SedeChip extends StatelessWidget {
  final String icono;
  final String nombre;
  final bool activa;
  final VoidCallback onTap;

  const _SedeChip({
    required this.icono,
    required this.nombre,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activa ? const Color(0xFF003B74) : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icono(icono),
              size: 16,
              color: activa ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              nombre,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: activa ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icono(String i) {
    switch (i) {
      case 'store': return Icons.store;
      case 'medical_services': return Icons.medical_services;
      case 'visibility': return Icons.visibility;
      case 'local_hospital': return Icons.local_hospital;
      case 'home': return Icons.home;
      case 'business': return Icons.business;
      case 'location_city': return Icons.location_city;
      case 'apartment': return Icons.apartment;
      default: return Icons.store;
    }
  }
}

class _ConfigView extends StatelessWidget {
  const _ConfigView();

  @override
  Widget build(BuildContext context) {
    return const ConfigScreen();
  }
}
