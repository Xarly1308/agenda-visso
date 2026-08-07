import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/config_provider.dart';
import '../utils/audit_logger.dart';
import '../utils/colombian_holidays.dart';

class ExcepcionesScreen extends StatefulWidget {
  const ExcepcionesScreen({super.key});

  @override
  State<ExcepcionesScreen> createState() => _ExcepcionesScreenState();
}

class _ExcepcionesScreenState extends State<ExcepcionesScreen> {
  DateTime _mesActual = DateTime.now();
  Set<String> _fechasExcepcion = {};
  final Map<String, String> _motivos = {};
  bool _cargando = true;
  bool _modoSeleccionMultiple = false;
  final Set<String> _seleccionTemporal = {};

  @override
  void initState() {
    super.initState();
    _cargarExcepciones();
  }

  Future<void> _cargarExcepciones() async {
    setState(() => _cargando = true);
    final config = context.read<ConfigProvider>();
    final excepciones = await config.cargarExcepciones();
    _fechasExcepcion = excepciones
        .where((e) => e.tipo == 'no_laborable')
        .map((e) => _formatDate(e.fecha))
        .toSet();
    for (final e in excepciones) {
      _motivos[_formatDate(e.fecha)] = e.motivo;
    }
    setState(() => _cargando = false);
  }

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  void _irAMes(DateTime mes) {
    setState(() => _mesActual = DateTime(mes.year, mes.month));
  }

  void _toggleModoSeleccion() {
    setState(() {
      _modoSeleccionMultiple = !_modoSeleccionMultiple;
      if (!_modoSeleccionMultiple) _seleccionTemporal.clear();
    });
  }

  void _toggleDiaSeleccion(DateTime dia) {
    final fs = _formatDate(dia);
    setState(() {
      if (_seleccionTemporal.contains(fs)) {
        _seleccionTemporal.remove(fs);
      } else {
        _seleccionTemporal.add(fs);
      }
    });
  }

  Future<void> _guardarSeleccionTemporal() async {
    if (_seleccionTemporal.isEmpty) return;

    final motivoCtrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Motivo (${_seleccionTemporal.length} día(s))'),
        content: TextField(
          controller: motivoCtrl,
          decoration: const InputDecoration(
            labelText: 'Motivo',
            hintText: 'Ej: Vacaciones, Capacitación, etc.',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (motivo == null || motivo.isEmpty) return;
    if (!mounted) return;

    final config = context.read<ConfigProvider>();
    int guardados = 0;
    for (final fs in _seleccionTemporal.toList()) {
      if (_fechasExcepcion.contains(fs)) continue;
      final partes = fs.split('-');
      final d = DateTime(int.parse(partes[0]), int.parse(partes[1]), int.parse(partes[2]));
      await config.agregarExcepcion(fecha: d, motivo: motivo);
      _fechasExcepcion.add(fs);
      _motivos[fs] = motivo;
      guardados++;
    }
    _seleccionTemporal.clear();
    _modoSeleccionMultiple = false;
    if (guardados > 0) {
      AuditLogger().registrar(
        categoria: 'configuracion',
        accion: 'crear',
        coleccion: 'excepciones',
        usuarioId: '',
        usuarioNombre: 'Desarrollador',
        detalles: '$guardados día(s) marcados como no laborables',
      );
    }
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$guardados día(s) marcados como no laborables')),
      );
    }
  }

  void _cancelarSeleccion() {
    setState(() {
      _modoSeleccionMultiple = false;
      _seleccionTemporal.clear();
    });
  }

  Future<void> _toggleDia(DateTime dia) async {
    final fechaStr = _formatDate(dia);
    if (_fechasExcepcion.contains(fechaStr)) {
      final accion = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Día no laborable: $fechaStr'),
          content: _motivos[fechaStr] != null ? Text('Motivo: ${_motivos[fechaStr]}') : null,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'modificar'),
              child: const Text('Modificar motivo'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'quitar'),
              child: Text('Restaurar día laboral', style: TextStyle(color: Colors.red.shade700)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      );
      if (accion == 'quitar') {
        if (!mounted) return;
        await context.read<ConfigProvider>().eliminarExcepcion(fechaStr);
        AuditLogger().registrar(
          categoria: 'configuracion',
          accion: 'eliminar',
          coleccion: 'excepciones',
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Excepción del $fechaStr eliminada (restaurado día laboral)',
        );
        setState(() {
          _fechasExcepcion.remove(fechaStr);
          _motivos.remove(fechaStr);
        });
      } else if (accion == 'modificar') {
        final motivoCtrl = TextEditingController(text: _motivos[fechaStr]);
        final nuevoMotivo = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Modificar motivo'),
            content: TextField(
              controller: motivoCtrl,
              decoration: const InputDecoration(
                labelText: 'Motivo',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim()),
                child: const Text('Guardar'),
              ),
            ],
          ),
        );
        if (nuevoMotivo == null || nuevoMotivo.isEmpty) return;
        if (!mounted) return;
        await context.read<ConfigProvider>().eliminarExcepcion(fechaStr);
        await context.read<ConfigProvider>().agregarExcepcion(fecha: dia, motivo: nuevoMotivo);
        AuditLogger().registrar(
          categoria: 'configuracion',
          accion: 'editar',
          coleccion: 'excepciones',
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Motivo de excepción del $fechaStr cambiado a "$nuevoMotivo"',
        );
        setState(() {
          _motivos[fechaStr] = nuevoMotivo;
        });
      }
    } else {
      final motivoCtrl = TextEditingController();
      final motivo = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Marcar día no laborable'),
          content: TextField(
            controller: motivoCtrl,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Ej: Vacaciones, Mantenimiento, etc.',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, motivoCtrl.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        ),
      );
      if (motivo == null || motivo.isEmpty) return;
      if (!mounted) return;
      await context.read<ConfigProvider>().agregarExcepcion(
        fecha: dia,
        motivo: motivo,
      );
      AuditLogger().registrar(
        categoria: 'configuracion',
        accion: 'crear',
        coleccion: 'excepciones',
        usuarioId: '',
        usuarioNombre: 'Desarrollador',
        detalles: 'Día $fechaStr marcado como no laborable: "$motivo"',
      );
      if (!mounted) return;
      setState(() {
        _fechasExcepcion.add(fechaStr);
        _motivos[fechaStr] = motivo;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Días no laborables'),
        actions: [
          IconButton(
            icon: Icon(_modoSeleccionMultiple ? Icons.close : Icons.select_all),
            tooltip: _modoSeleccionMultiple ? 'Salir de selección' : 'Seleccionar varios',
            onPressed: _toggleModoSeleccion,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final calendarHeight = _calcularAlturaCalendario();
    final body = Column(
      children: [
        _buildMesNavegacion(),
        const Divider(height: 1),
        SizedBox(
          height: calendarHeight,
          child: _buildCalendario(),
        ),
        if (_modoSeleccionMultiple)
          _buildSeleccionBar()
        else if (_motivos.isNotEmpty) ...[
          const Divider(height: 1),
          _buildLegend(),
          const Divider(height: 1),
          Flexible(
            flex: 0,
            child: Container(
              constraints: BoxConstraints(
                  maxHeight: _motivos.length > 5 ? 160 : _motivos.length * 28.0 + 8),
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: _motivos.entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.block, size: 16, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('${e.key}: ${e.value}',
                                style: const TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                    )).toList(),
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No hay días no laborables marcados. Toca un día del calendario para bloquearlo.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
      ],
    );

    if (!isDesktop) return body;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: body,
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          _leyendaItem(Colors.orange.shade100, Colors.orange.shade800, 'No laborable'),
          const SizedBox(width: 16),
          _leyendaItem(Colors.red.shade50, Colors.red.shade800, 'Festivo'),
          const SizedBox(width: 16),
          _leyendaItem(Colors.grey.shade100, Colors.grey, 'Finde'),
          const Spacer(),
          Text('${_motivos.length} día(s)',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _leyendaItem(Color bg, Color fg, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12, height: 12,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(3), border: Border.all(color: fg.withAlpha(100))),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: fg)),
      ],
    );
  }

  Widget _buildSeleccionBar() {
    return Container(
      color: Colors.blue.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${_seleccionTemporal.length} día(s) seleccionados',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            TextButton(
              onPressed: _cancelarSeleccion,
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: _seleccionTemporal.isEmpty ? null : _guardarSeleccionTemporal,
              child: Text('Guardar (${_seleccionTemporal.length})'),
            ),
          ],
        ),
      ),
    );
  }

  double _calcularAlturaCalendario() {
    final firstDay = DateTime(_mesActual.year, _mesActual.month, 1);
    final lastDay = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final startWeekday = (firstDay.weekday - 1) % 7;
    final daysInMonth = lastDay.day;
    final totalCells = startWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    return rows * 56.0 + 36.0;
  }

  Widget _buildMesNavegacion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month - 1)),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _mostrarSelectorMes,
              child: Text(
                DateFormat('MMMM yyyy', 'es').format(_mesActual),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month + 1)),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.calendar_today, size: 20),
            tooltip: 'Ir a fecha específica',
            onPressed: _mostrarSelectorMes,
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarSelectorMes() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _mesActual,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      locale: const Locale('es', 'ES'),
      helpText: 'Seleccionar mes',
    );
    if (picked != null) {
      _irAMes(picked);
    }
  }

  Widget _buildCalendario() {
    if (_cargando) return const Center(child: CircularProgressIndicator());

    final firstDay = DateTime(_mesActual.year, _mesActual.month, 1);
    final lastDay = DateTime(_mesActual.year, _mesActual.month + 1, 0);
    final startWeekday = (firstDay.weekday - 1) % 7;
    final daysInMonth = lastDay.day;

    const diasHeader = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    final celdas = <Widget>[];

    for (final d in diasHeader) {
      celdas.add(Center(
          child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))));
    }

    for (int i = 0; i < startWeekday; i++) {
      celdas.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final fecha = DateTime(_mesActual.year, _mesActual.month, day);
      final fechaStr = _formatDate(fecha);
      final esExcepcion = _fechasExcepcion.contains(fechaStr);
      final esSeleccionado = _seleccionTemporal.contains(fechaStr);
      final esFestivo = ColombianHolidays.esFestivo(fecha);
      final esFinde = fecha.weekday == DateTime.saturday || fecha.weekday == DateTime.sunday;
      final esHoy = _formatDate(DateTime.now()) == fechaStr;

      Color? colorFondo;
      Color colorTexto;

      if (esSeleccionado) {
        colorFondo = Colors.blue.shade200;
        colorTexto = Colors.white;
      } else if (esExcepcion) {
        colorFondo = Colors.orange.shade100;
        colorTexto = Colors.orange.shade900;
      } else if (esFestivo) {
        colorFondo = Colors.red.shade50;
        colorTexto = Colors.red.shade800;
      } else if (esHoy) {
        colorFondo = Theme.of(context).colorScheme.primary.withAlpha(15);
        colorTexto = Theme.of(context).colorScheme.primary;
      } else if (esFinde) {
        colorFondo = null;
        colorTexto = Colors.grey;
      } else {
        colorFondo = null;
        colorTexto = Colors.black87;
      }

      final nombreFestivo = esFestivo ? ColombianHolidays.nombreFestivo(fecha) : null;

      celdas.add(
        GestureDetector(
          onTap: () {
            if (_modoSeleccionMultiple) {
              _toggleDiaSeleccion(fecha);
            } else {
              _toggleDia(fecha);
            }
          },
          child: Container(
            margin: const EdgeInsets.all(1.5),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(6),
              border: esHoy && !esSeleccionado && !esExcepcion
                  ? Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(100))
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$day',
                    style: TextStyle(
                      color: colorTexto,
                      fontWeight: esExcepcion || esHoy || esSeleccionado || esFestivo
                          ? FontWeight.bold : null,
                      fontSize: 13,
                    )),
                if (nombreFestivo != null)
                  Text(nombreFestivo.substring(0, 1).toUpperCase(),
                      style: TextStyle(fontSize: 8, color: colorTexto.withAlpha(180))),
              ],
            ),
          ),
        ),
      );
    }

    const spacing = 24.0;
    final cellSize = (MediaQuery.of(context).size.width - spacing) / 7;
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 7,
      childAspectRatio: cellSize / 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      children: celdas,
    );
  }
}
