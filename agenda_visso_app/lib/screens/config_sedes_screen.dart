import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../models/sede.dart';
import 'sede_form_screen.dart';
import 'sede_horarios_screen.dart';

IconData _iconoDeSede(String icono) {
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

class ConfigSedesScreen extends StatelessWidget {
  const ConfigSedesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sedes')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onAdd(context),
        child: const Icon(Icons.add),
      ),
      body: config.cargando
          ? const Center(child: CircularProgressIndicator())
          : config.sedes.isEmpty
              ? const Center(
                  child: Text('No hay sedes registradas', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  itemCount: config.sedes.length,
                  itemBuilder: (context, i) {
                    final sede = config.sedes[i];
                    return ListTile(
                      leading: CircleAvatar(child: Icon(_iconoDeSede(sede.icono))),
                      title: Text(sede.nombre),
                      subtitle: Text('${sede.direccion}\n${sede.telefono ?? ""}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _onEdit(context, sede),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => _onDelete(context, config, sede),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SedeHorariosScreen(sede: sede),
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  void _onAdd(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SedeFormScreen()),
    );
    if (result == true && context.mounted) {
      context.read<ConfigProvider>().cargarSedes();
    }
  }

  void _onEdit(BuildContext context, Sede sede) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SedeFormScreen(sede: sede)),
    );
    if (result == true && context.mounted) {
      context.read<ConfigProvider>().cargarSedes();
    }
  }

  void _onDelete(BuildContext context, ConfigProvider config, Sede sede) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar sede'),
        content: Text('¿Desactivar "${sede.nombre}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              config.eliminarSede(sede.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
