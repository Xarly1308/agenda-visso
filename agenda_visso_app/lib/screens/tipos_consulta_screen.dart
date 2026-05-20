import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/tipo_consulta.dart';
import '../services/firestore_service.dart';

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
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tipos de consulta'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: _agregar),
        ],
      ),
      body: _cargando
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
                ),
    );
  }
}
