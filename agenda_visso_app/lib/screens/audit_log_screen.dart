import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/firestore_rest_service.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _rest = FirestoreRestService();
  List<Map<String, dynamic>> _logs = [];
  List<String> _franquiciaIds = [];
  bool _cargando = true;
  String? _franquiciaFiltro;
  String? _coleccionFiltro;

  static const _colecciones = {
    'citas': 'Citas',
    'franquicias': 'Franquicias',
    'profesionales': 'Profesionales',
    'sedes': 'Sedes',
    'horarios': 'Horarios',
    'tipos_consulta': 'Tipos de consulta',
    'excepciones': 'Excepciones',
    'pacientes': 'Pacientes',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      _logs = await _rest.getAuditLogs();
      final ids = <String>{};
      for (final l in _logs) {
        final fid = l['franquiciaId'] as String?;
        if (fid != null && fid.isNotEmpty) ids.add(fid);
      }
      _franquiciaIds = ids.toList()..sort();
    } catch (e) {
      debugPrint('Error cargando datos audit: $e');
    }
    if (mounted) setState(() => _cargando = false);
  }

  List<Map<String, dynamic>> get _logsFiltrados {
    var resultado = _logs;
    if (_franquiciaFiltro != null) {
      resultado = resultado.where((l) => l['franquiciaId'] == _franquiciaFiltro).toList();
    }
    if (_coleccionFiltro != null) {
      resultado = resultado.where((l) => l['coleccion'] == _coleccionFiltro).toList();
    }
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    final logsFiltrados = _logsFiltrados;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de cambios'),
        actions: [
          if (_franquiciaFiltro != null || _coleccionFiltro != null)
            TextButton(
              onPressed: () => setState(() {
                _franquiciaFiltro = null;
                _coleccionFiltro = null;
              }),
              child: const Text('Limpiar'),
            ),
          if (_franquiciaIds.length > 1)
            PopupMenuButton<String>(
              icon: const Icon(LucideIcons.building),
              tooltip: 'Filtrar por franquicia',
              onSelected: (v) => setState(() => _franquiciaFiltro = v == '_all' ? null : v),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: '_all',
                  child: Row(
                    children: [
                      Icon(_franquiciaFiltro == null ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 8),
                      const Text('Todas las franquicias'),
                    ],
                  ),
                ),
                for (final fid in _franquiciaIds)
                  PopupMenuItem(
                    value: fid,
                    child: Row(
                      children: [
                        Icon(_franquiciaFiltro == fid ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        Text(fid),
                      ],
                    ),
                  ),
              ],
            ),
          PopupMenuButton<String>(
            icon: const Icon(LucideIcons.listFilter),
            tooltip: 'Filtrar por colección',
            onSelected: (v) => setState(() => _coleccionFiltro = v == '_all' ? null : v),
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: '_all',
                child: Row(
                  children: [
                    Icon(_coleccionFiltro == null ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                        size: 18, color: Colors.teal),
                    const SizedBox(width: 8),
                    const Text('Todas las colecciones'),
                  ],
                ),
              ),
              for (final entry in _colecciones.entries)
                PopupMenuItem(
                  value: entry.key,
                  child: Row(
                    children: [
                      Icon(_coleccionFiltro == entry.key ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18, color: Colors.teal),
                      const SizedBox(width: 8),
                      Text(entry.value),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : logsFiltrados.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.fileText, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        _logs.isEmpty ? 'No hay registros' : 'No hay registros para este filtro',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    if (_franquiciaFiltro != null || _coleccionFiltro != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        color: Colors.teal.withAlpha(15),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.filter, size: 16, color: Colors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${logsFiltrados.length} de ${_logs.length} registros'
                                '${_franquiciaFiltro != null ? ' — Franquicia: $_franquiciaFiltro' : ''}'
                                '${_coleccionFiltro != null ? ' — ${_colecciones[_coleccionFiltro]}' : ''}',
                                style: const TextStyle(fontSize: 13, color: Colors.teal),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: logsFiltrados.length,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemBuilder: (context, index) {
                          final log = logsFiltrados[index];
                          return _AuditLogTile(log: log);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final Map<String, dynamic> log;

  const _AuditLogTile({required this.log});

  IconData _iconoAccion(String accion) {
    switch (accion) {
      case 'crear': return LucideIcons.plusCircle;
      case 'editar': return LucideIcons.pencil;
      case 'eliminar': return LucideIcons.trash2;
      default: return LucideIcons.circleDot;
    }
  }

  Color _colorAccion(String accion) {
    switch (accion) {
      case 'crear': return Colors.green;
      case 'editar': return Colors.orange;
      case 'eliminar': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final accion = log['accion'] as String? ?? '';
    final coleccion = log['coleccion'] as String? ?? '';
    final usuario = log['usuarioNombre'] as String? ?? 'Desconocido';
    final timestamp = log['timestamp'] as String? ?? '';
    final detalles = log['detalles'] as String?;
    final franquiciaId = log['franquiciaId'] as String?;

    DateTime? fecha;
    try {
      fecha = DateTime.parse(timestamp);
    } catch (_) {}

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _colorAccion(accion).withAlpha(30),
        child: Icon(_iconoAccion(accion), color: _colorAccion(accion), size: 20),
      ),
      title: Text(
        '${accion.toUpperCase()} $coleccion',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Por: $usuario', style: const TextStyle(fontSize: 12)),
          if (detalles != null && detalles.isNotEmpty)
            Text(detalles, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (fecha != null)
            Text(
              DateFormat('dd/MM HH:mm').format(fecha),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          if (franquiciaId != null && franquiciaId.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey.withAlpha(20),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                franquiciaId,
                style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
              ),
            ),
        ],
      ),
    );
  }
}
