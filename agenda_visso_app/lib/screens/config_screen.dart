import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/agenda_provider.dart';
import '../services/app_update_service.dart';
import 'config_sedes_screen.dart';
import 'excepciones_screen.dart';
import 'resumen_horarios_screen.dart';
import 'tipos_consulta_screen.dart';

const String kAppVersion = '1.0.0';

class ConfigScreen extends StatelessWidget {
  const ConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              _CardButton(
                icon: Icons.store,
                title: 'Gestionar Sedes',
                subtitle: 'Agregar, editar y eliminar sedes',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigSedesScreen())),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.calendar_month,
                title: 'Horarios por sede',
                subtitle: 'Configurar días y horarios de atención por sede',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumenHorariosScreen())),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.block,
                title: 'Días no laborables',
                subtitle: 'Marcar vacaciones, festivos y ausencias',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExcepcionesScreen())),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.local_hospital,
                title: 'Tipos de consulta',
                subtitle: 'Agregar o eliminar tipos de consulta',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TiposConsultaScreen())),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.info_outline,
                title: 'Acerca de',
                subtitle: 'Versión $kAppVersion — información y actualizaciones',
                color: Colors.blueGrey,
                onTap: () => _mostrarAcercaDe(context),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.cleaning_services,
                title: 'Limpiar citas antiguas',
                subtitle: 'Eliminar citas de días anteriores al de hoy',
                color: Colors.brown,
                onTap: () => _confirmarLimpiar(context, 'antiguas'),
              ),
              const SizedBox(height: 12),
              _CardButton(
                icon: Icons.restart_alt,
                title: 'Resetear semana actual',
                subtitle: 'Eliminar todas las citas de esta semana',
                color: Colors.red,
                onTap: () => _confirmarLimpiar(context, 'semana'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.red.shade50,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(Icons.logout, color: Colors.white),
                ),
                title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
                onTap: () => context.read<AuthProvider>().logout(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CardButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CardButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withAlpha(30),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

void _mostrarAcercaDe(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Acerca de'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Image.asset('assets/visso_logo.png', height: 64),
                const SizedBox(height: 8),
                const Text('Visso Agenda', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Versión: $kAppVersion'),
          const SizedBox(height: 4),
          const Text('App profesional para gestión de citas'),
          const Divider(height: 24),
          const Text('© 2026 Visso', style: TextStyle(color: Colors.grey)),
        ],
      ),
      actions: [
        OutlinedButton.icon(
          icon: const Icon(Icons.update, size: 18),
          label: const Text('Buscar actualizaciones'),
          onPressed: () async {
            Navigator.pop(ctx);
            _buscarActualizacion(context);
          },
        ),
        FilledButton(
          child: const Text('Cerrar'),
          onPressed: () => Navigator.pop(ctx),
        ),
      ],
    ),
  );
}

Future<void> _buscarActualizacion(BuildContext context) async {
  final service = AppUpdateService();
  final version = await service.getLatestVersion();
  if (version == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo verificar actualizaciones'), behavior: SnackBarBehavior.floating),
      );
    }
    return;
  }
  final latestVersion = version['version'];
  final apkUrl = version['apkUrl'];
  final notas = version['notas'];
  if (latestVersion == null || apkUrl == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Información de versión no disponible'), behavior: SnackBarBehavior.floating),
      );
    }
    return;
  }
  if (!service.isUpdateAvailable(latestVersion, kAppVersion)) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ya tienes la última versión ($kAppVersion)'), behavior: SnackBarBehavior.floating),
      );
    }
    return;
  }
  if (!context.mounted) return;
  final descargar = await showDialog<bool>(
    context: context,
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
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ahora no')),
        FilledButton.icon(
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Descargar'),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (descargar != true || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Descargando actualización...'), behavior: SnackBarBehavior.floating),
  );
  await service.downloadUpdate(apkUrl);
}

void _confirmarLimpiar(BuildContext context, String tipo) {
  final titulo = tipo == 'semana' ? 'Resetear semana actual' : 'Limpiar citas antiguas';
  final mensaje = tipo == 'semana'
      ? '¿Eliminar todas las citas de esta semana? Esta acción no se puede deshacer.'
      : '¿Eliminar todas las citas de días anteriores a hoy? Esta acción no se puede deshacer.';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            final agenda = context.read<AgendaProvider>();
            if (tipo == 'semana') {
              agenda.limpiarSemana();
            } else {
              agenda.limpiarAntiguas();
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(titulo), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
