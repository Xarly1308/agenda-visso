import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/agenda_provider.dart';
import '../providers/auth_provider.dart';
import '../services/firestore_rest_service.dart';

class _InfoColeccion {
  final IconData icono;
  final String nombre;
  final String descripcion;
  const _InfoColeccion(this.icono, this.nombre, this.descripcion);
}

class LimpiarDatosScreen extends StatefulWidget {
  const LimpiarDatosScreen({super.key});

  @override
  State<LimpiarDatosScreen> createState() => _LimpiarDatosScreenState();
}

class _LimpiarDatosScreenState extends State<LimpiarDatosScreen> {
  final Set<String> _seleccionadas = {};
  bool _procesando = false;

  static const _colecciones = <String, _InfoColeccion>{
    'citas': _InfoColeccion(Icons.calendar_today, 'Citas', 'Todas las citas agendadas en esta franquicia'),
    'sedes': _InfoColeccion(Icons.store, 'Sedes', 'Sedes registradas en esta franquicia'),
    'horarios': _InfoColeccion(Icons.schedule, 'Horarios', 'Horarios de atención configurados'),
    'tipos_consulta': _InfoColeccion(LucideIcons.heartPulse, 'Tipos de consulta', 'Tipos de consulta configurados'),
    'excepciones': _InfoColeccion(Icons.block, 'Excepciones', 'Días no laborables marcados'),
    'pacientes': _InfoColeccion(Icons.people, 'Pacientes', 'Pacientes registrados en esta franquicia'),
    'notificaciones': _InfoColeccion(Icons.notifications, 'Notificaciones', 'Historial de notificaciones'),
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final nombreFranquicia = auth.franquiciaNombre ?? auth.franquiciaId ?? 'Desconocida';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Limpiar datos'),
        actions: [
          if (_seleccionadas.isNotEmpty)
            TextButton.icon(
              onPressed: _procesando ? null : _confirmarLimpiar,
              icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.white),
              label: Text('Eliminar (${_seleccionadas.length})', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: _procesando
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Eliminando datos...', style: TextStyle(fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: Colors.orange.shade50,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(LucideIcons.alertTriangle, color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Franquicia: $nombreFranquicia',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Solo se eliminarán los datos de esta franquicia.',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _colecciones.length,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemBuilder: (context, index) {
                      final entry = _colecciones.entries.elementAt(index);
                      final key = entry.key;
                      final info = entry.value;
                      final checked = _seleccionadas.contains(key);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(info.nombre, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(info.descripcion, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                        secondary: Icon(info.icono, color: checked ? Colors.red : Colors.grey.shade400),
                        controlAffinity: ListTileControlAffinity.trailing,
                        activeColor: Colors.red,
                        onChanged: (v) {
                          setState(() {
                            if (checked) {
                              _seleccionadas.remove(key);
                            } else {
                              _seleccionadas.add(key);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmarLimpiar() async {
    final nombreFranquicia = context.read<AuthProvider>().franquiciaNombre ?? 'esta franquicia';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Estás seguro?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.alertTriangle, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text('Se eliminarán los siguientes datos de $nombreFranquicia:'),
            const SizedBox(height: 12),
            ..._seleccionadas.map((s) {
              final info = _colecciones[s]!;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(info.icono, size: 18, color: Colors.red.shade300),
                    const SizedBox(width: 10),
                    Text(info.nombre),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text(
              'Esta acción NO se puede deshacer.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    setState(() => _procesando = true);

    try {
      final agenda = context.read<AgendaProvider>();
      await agenda.limpiarDatos(_seleccionadas.toList());
    } catch (e) {
      debugPrint('Error limpiando datos: $e');
    }

    if (mounted) {
      setState(() => _procesando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limpieza completada'), behavior: SnackBarBehavior.floating),
      );
      Navigator.pop(context);
    }
  }
}
