import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/config_provider.dart';

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
              child: Text('Quitar día no laborable', style: TextStyle(color: Colors.red.shade700)),
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
      body: Column(
        children: [
          _buildMesNavegacion(),
          const Divider(height: 1),
          Expanded(child: _buildCalendario()),
          if (_modoSeleccionMultiple)
            _buildSeleccionBar()
          else if (_motivos.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Text('Días bloqueados:', style: Theme.of(context).textTheme.titleSmall),
                  const Spacer(),
                  Text('${_motivos.length} día(s)',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
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
          ],
        ],
      ),
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

  Widget _buildMesNavegacion() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () =>
                setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month - 1)),
          ),
          Text(
            DateFormat('MMMM yyyy', 'es').format(_mesActual),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () =>
                setState(() => _mesActual = DateTime(_mesActual.year, _mesActual.month + 1)),
          ),
        ],
      ),
    );
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
          child: Text(d, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))));
    }

    for (int i = 0; i < startWeekday; i++) {
      celdas.add(const SizedBox());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final fecha = DateTime(_mesActual.year, _mesActual.month, day);
      final fechaStr = _formatDate(fecha);
      final esExcepcion = _fechasExcepcion.contains(fechaStr);
      final esSeleccionado = _seleccionTemporal.contains(fechaStr);
      final esFinde = fecha.weekday == 6 || fecha.weekday == 7;
      final esHoy = _formatDate(DateTime.now()) == fechaStr;

      Color? colorFondo;
      if (esSeleccionado) {
        colorFondo = Colors.blue.shade200;
      } else if (esExcepcion) {
        colorFondo = Colors.orange.shade100;
      } else if (esHoy) {
        colorFondo = Colors.teal.shade50;
      }

      Color colorTexto;
      if (esSeleccionado) {
        colorTexto = Colors.white;
      } else if (esExcepcion) {
        colorTexto = Colors.orange.shade800;
      } else if (esFinde) {
        colorTexto = Colors.grey;
      } else {
        colorTexto = Colors.black87;
      }

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
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: colorFondo,
              borderRadius: BorderRadius.circular(8),
              border: esHoy && !esSeleccionado ? Border.all(color: Colors.teal) : null,
            ),
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  color: colorTexto,
                  fontWeight: esExcepcion || esHoy || esSeleccionado ? FontWeight.bold : null,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      childAspectRatio: 1,
      padding: const EdgeInsets.all(8),
      children: celdas,
    );
  }
}
