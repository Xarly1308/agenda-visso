import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../models/tipo_consulta.dart';
import '../services/firestore_service.dart';
import '../utils/audit_logger.dart';

class TiposConsultaScreen extends StatefulWidget {
  const TiposConsultaScreen({super.key});

  @override
  State<TiposConsultaScreen> createState() => _TiposConsultaScreenState();
}

class _TiposConsultaScreenState extends State<TiposConsultaScreen> {
  final _service = FirestoreService();
  final _uuid = const Uuid();
  List<TipoConsulta> _tipos = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      _tipos = await _service.getTiposConsulta();
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _agregar() async {
    final ctrl = TextEditingController();
    final nombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo tipo de consulta'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (nombre == null || nombre.isEmpty) return;
    final tipo = TipoConsulta(id: _uuid.v4(), nombre: nombre);
    await _service.addTipoConsulta(tipo);
    AuditLogger().registrar(
      categoria: 'configuracion',
      accion: 'crear',
      coleccion: 'tipos_consulta',
      documentoId: tipo.id,
      usuarioId: '',
      usuarioNombre: 'Desarrollador',
      detalles: 'Tipo de consulta "$nombre" creado',
    );
    await _cargar();
  }

  Future<void> _eliminar(TipoConsulta tipo) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tipo'),
        content: Text('¿Eliminar "${tipo.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await _service.deleteTipoConsulta(tipo.id);
    AuditLogger().registrar(
      categoria: 'configuracion',
      accion: 'eliminar',
      coleccion: 'tipos_consulta',
      documentoId: tipo.id,
      usuarioId: '',
      usuarioNombre: 'Desarrollador',
      detalles: 'Tipo de consulta "${tipo.nombre}" desactivado',
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;
    final body = _cargando
        ? const Center(child: CircularProgressIndicator())
        : _tipos.isEmpty
            ? const Center(child: Text('No hay tipos de consulta', style: TextStyle(color: Colors.grey)))
            : ListView.builder(
                itemCount: _tipos.length,
                itemBuilder: (_, i) {
                  final tipo = _tipos[i];
                  return ListTile(
                    title: Text(tipo.nombre),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminar(tipo),
                    ),
                  );
                },
              );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de consulta'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregar,
        icon: const Icon(LucideIcons.plus),
        label: const Text('Agregar tipo'),
      ),
      body: isDesktop
          ? Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: body,
              ),
            )
          : body,
    );
  }
}
