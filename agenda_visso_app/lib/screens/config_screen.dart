import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/agenda_provider.dart';
import '../services/app_update_service.dart';
import 'config_sedes_screen.dart';
import 'excepciones_screen.dart';
import 'resumen_horarios_screen.dart';
import 'tipos_consulta_screen.dart';

const String kAppVersion = '1.3.6';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  int _acercaDeTaps = 0;
  bool _mostrarDev = false;

  void _onAcercaDeTap() {
    _acercaDeTaps++;
    if (_acercaDeTaps >= 7) {
      if (!_mostrarDev) {
        setState(() => _mostrarDev = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Modo desarrollador activado!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      _acercaDeTaps = 0;
    } else {
      final restantes = 7 - _acercaDeTaps;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$restantes toques para activar modo desarrollador'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              _SectionHeader(title: 'Configuración'),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.store,
                title: 'Gestionar Sedes',
                subtitle: 'Agregar, editar y eliminar sedes',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigSedesScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.calendar_month,
                title: 'Horarios por sede',
                subtitle: 'Configurar días y horarios de atención por sede',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumenHorariosScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.block,
                title: 'Días no laborables',
                subtitle: 'Marcar vacaciones, festivos y ausencias',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExcepcionesScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.local_hospital,
                title: 'Tipos de consulta',
                subtitle: 'Agregar o eliminar tipos de consulta',
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TiposConsultaScreen())),
              ),

              const SizedBox(height: 24),
              _SectionHeader(title: 'Mantenimiento'),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.cleaning_services,
                title: 'Limpiar citas antiguas',
                subtitle: 'Eliminar citas de días anteriores al de hoy',
                color: Colors.brown,
                onTap: () => _confirmarLimpiar(context, 'antiguas'),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.restart_alt,
                title: 'Resetear semana actual',
                subtitle: 'Eliminar todas las citas de esta semana',
                color: Colors.red,
                onTap: () => _confirmarLimpiar(context, 'semana'),
              ),

              const SizedBox(height: 24),
              _SectionHeader(title: 'Compartir'),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.share,
                title: 'Enviar invitación por WhatsApp',
                subtitle: 'Compartir link de registro con pacientes',
                color: Colors.green,
                onTap: () => _enviarInvitacionWhatsApp(context),
              ),

              const SizedBox(height: 24),
              _SectionHeader(title: 'Información'),
              const SizedBox(height: 8),
              _CardButton(
                icon: Icons.info_outline,
                title: 'Acerca de',
                subtitle: 'Versión $kAppVersion — información y actualizaciones',
                color: Colors.blueGrey,
                onTap: () {
                  _onAcercaDeTap();
                  _mostrarAcercaDe(context);
                },
              ),

              if (_mostrarDev) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'Desarrollador', color: Colors.red),
                const SizedBox(height: 8),
                _CardButton(
                  icon: Icons.cleaning_services,
                  title: 'Limpiar datos',
                  subtitle: 'Selecciona qué datos eliminar',
                  color: Colors.red,
                  onTap: () => _mostrarSelectorLimpieza(context),
                ),
              ],

              const SizedBox(height: 16),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color? color;

  const _SectionHeader({required this.title, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.grey.shade600;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: c,
          letterSpacing: 1.2,
        ),
      ),
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

  SharedPreferences.getInstance().then((p) => p.setString('ota_attempted_version', kAppVersion));

  double progreso = 0;
  String estado = 'Descargando...';

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: _DownloadDialog(service: service, apkUrl: apkUrl),
      );
    },
  );
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
              SnackBar(content: Text('$titulo completado'), behavior: SnackBarBehavior.floating),
            );
          },
          child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

Future<void> _mostrarSelectorLimpieza(BuildContext context) async {
  final colecciones = <String, _InfoColeccion>{
    'citas': _InfoColeccion(Icons.calendar_today, 'Citas', 'Todas las citas agendadas'),
    'sedes': _InfoColeccion(Icons.store, 'Sedes', 'Todas las sedes registradas'),
    'horarios': _InfoColeccion(Icons.schedule, 'Horarios', 'Horarios de atención configurados'),
    'tipos_consulta': _InfoColeccion(Icons.local_hospital, 'Tipos de consulta', 'Tipos de consulta configurados'),
    'excepciones': _InfoColeccion(Icons.block, 'Excepciones', 'Días no laborables marcados'),
    'pacientes': _InfoColeccion(Icons.people, 'Pacientes', 'Todos los pacientes registrados'),
    'notificaciones': _InfoColeccion(Icons.notifications, 'Notificaciones', 'Historial de notificaciones'),
  };

  final seleccionadas = await showDialog<Set<String>>(
    context: context,
    builder: (ctx) {
      final seleccion = <String>{};
      return StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Limpiar datos'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: colecciones.entries.map((e) {
                final key = e.key;
                final info = e.value;
                final checked = seleccion.contains(key);
                return CheckboxListTile(
                  value: checked,
                  title: Text(info.nombre),
                  subtitle: Text(info.descripcion, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  secondary: Icon(info.icono, color: Colors.red.shade300),
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (_) {
                    setDialogState(() {
                      if (checked) {
                        seleccion.remove(key);
                      } else {
                        seleccion.add(key);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton.icon(
              icon: const Icon(Icons.delete_sweep, size: 18),
              label: Text('Limpiar (${seleccion.length})'),
              onPressed: seleccion.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, seleccion),
            ),
          ],
        ),
      );
    },
  );

  if (seleccionadas == null || seleccionadas.isEmpty || !context.mounted) return;

  final confirmar = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('¿Estás seguro?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 12),
          const Text('Se eliminarán los siguientes datos:'),
          const SizedBox(height: 8),
          ...seleccionadas.map((s) {
            final info = colecciones[s]!;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(info.icono, size: 18, color: Colors.red.shade300),
                  const SizedBox(width: 8),
                  Text(info.nombre),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text('Esta acción NO se puede deshacer.', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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

  if (confirmar != true || !context.mounted) return;

  final agenda = context.read<AgendaProvider>();
  await agenda.limpiarDatos(seleccionadas.toList());
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Limpieza completada'), behavior: SnackBarBehavior.floating),
    );
  }
}

class _InfoColeccion {
  final IconData icono;
  final String nombre;
  final String descripcion;
  const _InfoColeccion(this.icono, this.nombre, this.descripcion);
}

class _DownloadDialog extends StatefulWidget {
  final AppUpdateService service;
  final String apkUrl;
  const _DownloadDialog({required this.service, required this.apkUrl});

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

class _DownloadDialogState extends State<_DownloadDialog> {
  double _progreso = 0;
  String _estado = 'Conectando...';
  bool _termino = false;

  @override
  void initState() {
    super.initState();
    _iniciar();
  }

  Future<void> _iniciar() async {
    final ok = await widget.service.downloadUpdate(
      widget.apkUrl,
      onProgress: (p, s) {
        if (!mounted) return;
        setState(() {
          _progreso = p;
          _estado = s == 'INSTALLING' ? 'Instalando...' : 'Descargando...';
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _termino = true;
      if (ok) {
        _estado = 'Actualización descargada.';
        _progreso = 1.0;
      } else {
        _estado = 'Error al actualizar';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_termino && _progreso == 1.0 ? 'Actualización lista' : 'Actualizando'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_termino) ...[
            LinearProgressIndicator(value: _progreso > 0 ? _progreso : null),
            const SizedBox(height: 16),
            Text(_estado),
            if (_progreso > 0)
              Text('${(_progreso * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            const Text('No cierres la aplicación', style: TextStyle(fontSize: 12, color: Colors.orange)),
          ],
          if (_termino && _progreso == 1.0) ...[
            const Icon(Icons.check_circle, color: Colors.green, size: 48),
            const SizedBox(height: 12),
            const Text('La descarga ha finalizado.'),
            const SizedBox(height: 4),
            Text(_estado, style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 8),
            const Text('Android mostrará una ventana para instalar.\n'
                'Presiona "Instalar" y la app se reiniciará sola.',
                style: TextStyle(fontSize: 13, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
          if (_termino && _progreso < 1.0) ...[
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 12),
            Text(_estado),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ],
      ),
    );
  }
}

Future<void> _enviarInvitacionWhatsApp(BuildContext context) async {
  final mensaje = Uri.encodeComponent(
    '¡Hola! Te invitamos a registrar tus datos y agendar tu cita en nuestra plataforma:\n\n'
    'https://agendavisso.web.app\n\n'
    'Agenda tu cita de forma rápida y sencilla.',
  );
  final uri = Uri.parse('https://wa.me/?text=$mensaje');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir WhatsApp. Verifica que esté instalado.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
