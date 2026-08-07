import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/audit_logger.dart';

class AuditConfigScreen extends StatefulWidget {
  const AuditConfigScreen({super.key});

  @override
  State<AuditConfigScreen> createState() => _AuditConfigScreenState();
}

class _AuditConfigScreenState extends State<AuditConfigScreen> {
  final _logger = AuditLogger();

  static const _descriciones = {
    'citas': 'Crear, editar estado, reagendar, eliminar citas',
    'franquicias': 'Crear, editar, eliminar franquicias',
    'profesionales': 'Crear, editar, eliminar profesionales',
    'sedes': 'Crear, editar, eliminar sedes',
    'horarios': 'Guardar horarios de sede',
    'configuracion': 'Tipos de consulta y excepciones de agenda',
    'limpieza': 'Limpieza masiva de datos (semana, antiguas, todo)',
  };

  static const _iconos = {
    'citas': LucideIcons.calendarDays,
    'franquicias': LucideIcons.building,
    'profesionales': LucideIcons.users,
    'sedes': LucideIcons.store,
    'horarios': LucideIcons.clock,
    'configuracion': LucideIcons.settings,
    'limpieza': LucideIcons.eraser,
  };

  @override
  void initState() {
    super.initState();
    _logger.cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar registro'),
        actions: [
          TextButton(
            onPressed: () async {
              for (final key in AuditLogger.categorias.keys) {
                if (!_logger.estaHabilitada(key)) {
                  await _logger.toggleCategoria(key);
                }
              }
              setState(() {});
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Todas las categorías activadas'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Activar todas'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(LucideIcons.scrollText, color: Colors.teal.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Registro de cambios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Selecciona qué operaciones se registran en el historial. '
                    'Las categorías desactivadas no guardarán cambios.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...AuditLogger.categorias.entries.map((entry) {
            final habilitada = _logger.estaHabilitada(entry.key);
            return Card(
              child: SwitchListTile(
                secondary: CircleAvatar(
                  backgroundColor: habilitada
                      ? Colors.teal.withAlpha(30)
                      : Colors.grey.withAlpha(30),
                  child: Icon(
                    _iconos[entry.key] ?? LucideIcons.circleDot,
                    color: habilitada ? Colors.teal : Colors.grey,
                    size: 20,
                  ),
                ),
                title: Text(
                  entry.value,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _descriciones[entry.key] ?? '',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                value: habilitada,
                onChanged: (value) async {
                  await _logger.toggleCategoria(entry.key);
                  setState(() {});
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
