import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/auth_provider.dart';
import '../providers/agenda_provider.dart';
import '../providers/config_provider.dart';
import '../providers/notificacion_provider.dart';
import '../services/app_update_service.dart';
import '../services/functions_service.dart';
import '../services/firestore_rest_service.dart';
import '../utils/audit_logger.dart';
import 'config_sedes_screen.dart';
import 'gestionar_franquicias_screen.dart';
import 'excepciones_screen.dart';
import 'resumen_horarios_screen.dart';
import 'tipos_consulta_screen.dart';
import 'limpiar_datos_screen.dart';
import 'audit_log_screen.dart';
import 'audit_config_screen.dart';

const String kAppVersion = '1.3.11';

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  List<Map<String, dynamic>> _franquicias = [];
  bool _cargandoFranquicias = false;

  @override
  void initState() {
    super.initState();
    _cargarFranquicias();
  }

  Future<void> _cargarFranquicias() async {
    setState(() => _cargandoFranquicias = true);
    try {
      final f = await FirestoreRestService().getTodasFranquicias();
      if (mounted) setState(() => _franquicias = f);
    } catch (_) {}
    if (mounted) setState(() => _cargandoFranquicias = false);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final auth = context.watch<AuthProvider>();
    final esDesarrollador = auth.esDesarrollador;
    final viendoOtra = auth.viendoOtraFranquicia;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            children: [
              _SectionHeader(title: 'Configuración'),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.store,
                title: 'Gestionar Sedes',
                subtitle: 'Agregar, editar y eliminar sedes',
                color: primary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConfigSedesScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.calendar,
                title: 'Horarios por sede',
                subtitle: 'Configurar días y horarios de atención por sede',
                color: Colors.indigo,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ResumenHorariosScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.ban,
                title: 'Días no laborables',
                subtitle: 'Marcar vacaciones, festivos y ausencias',
                color: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExcepcionesScreen())),
              ),
              const SizedBox(height: 8),
              _CardButton(
                 icon: LucideIcons.heartPulse,
                title: 'Tipos de consulta',
                subtitle: 'Agregar o eliminar tipos de consulta',
                color: primary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TiposConsultaScreen())),
              ),

              const SizedBox(height: 24),
              _SectionHeader(title: 'Mantenimiento'),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.eraser,
                title: 'Limpiar citas antiguas',
                subtitle: 'Eliminar citas de días anteriores al de hoy',
                color: Colors.brown,
                onTap: () => _confirmarLimpiar(context, 'antiguas'),
              ),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.rotateCcw,
                title: 'Resetear semana actual',
                subtitle: 'Eliminar todas las citas de esta semana',
                color: Colors.red,
                onTap: () => _confirmarLimpiar(context, 'semana'),
              ),

              const SizedBox(height: 24),
              _SectionHeader(title: 'Compartir'),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.share2,
                title: 'Enviar invitación por WhatsApp',
                subtitle: 'Compartir link de registro con pacientes',
                color: Colors.green,
                onTap: () => _enviarInvitacionWhatsApp(context),
              ),

if (esDesarrollador) ...[
                const SizedBox(height: 24),
                _SectionHeader(title: 'Desarrollador', color: Colors.red),
                const SizedBox(height: 8),
                if (viendoOtra) ...[
                  Card(
                    color: Colors.orange.shade50,
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        child: Icon(LucideIcons.eye, color: Colors.white, size: 20),
                      ),
                      title: Text('Viendo: ${auth.franquiciaNombre ?? auth.franquiciaId}',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: const Text('Estás visualizando otra franquicia'),
                      trailing: TextButton(
                        onPressed: () async {
                          await auth.volverAMiFranquicia();
                          if (context.mounted) {
                            final uid = auth.user?.uid;
                            if (uid != null) {
                              context.read<ConfigProvider>().inicializar(uid);
                              context.read<AgendaProvider>().inicializar(uid, nombre: auth.nombreUsuario);
                              context.read<NotificacionProvider>().inicializar(uid);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Volviendo a tu franquicia'), behavior: SnackBarBehavior.floating),
                            );
                          }
                        },
                        child: const Text('Volver a la mía'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _cargandoFranquicias
                    ? const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()))
                    : Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.deepPurple.withAlpha(30),
                            child: const Icon(LucideIcons.building, color: Colors.deepPurple),
                          ),
                          title: const Text('Cambiar franquicia', style: TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(viendoOtra
                              ? 'Ver datos de otra franquicia'
                              : 'Franquicia actual: ${auth.franquiciaNombre ?? auth.franquiciaId}'),
                          trailing: const Icon(LucideIcons.chevronRight),
                          onTap: () => _mostrarSelectorFranquicia(context),
                        ),
                      ),
                const SizedBox(height: 8),
                _CardButton(
                  icon: LucideIcons.building,
                  title: 'Gestionar franquicias',
                  subtitle: 'Ver, agregar, editar franquicias y profesionales',
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GestionarFranquiciasScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _CardButton(
                  icon: LucideIcons.eraser,
                  title: 'Limpiar datos',
                  subtitle: 'Selecciona qué datos eliminar de la franquicia activa',
                  color: Colors.red,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LimpiarDatosScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _CardButton(
                  icon: LucideIcons.scrollText,
                  title: 'Registro de cambios',
                  subtitle: 'Ver historial de acciones realizadas',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditLogScreen()),
                  ),
                ),
                const SizedBox(height: 8),
                _CardButton(
                  icon: LucideIcons.slidersHorizontal,
                  title: 'Configurar registro',
                  subtitle: 'Seleccionar qué operaciones se registran',
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuditConfigScreen()),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              _SectionHeader(title: 'Información'),
              const SizedBox(height: 8),
              _CardButton(
                icon: LucideIcons.info,
                title: 'Acerca de',
                subtitle: 'Versión $kAppVersion — información y actualizaciones',
                color: Colors.blueGrey,
                onTap: () => _mostrarAcercaDe(context),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
        const Divider(height: 1),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Card(
              color: Colors.red.shade50,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: Colors.red,
                  child: Icon(LucideIcons.logOut, color: Colors.white, size: 22),
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
        trailing: const Icon(LucideIcons.chevronRight),
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
          icon: const Icon(LucideIcons.refreshCw, size: 18),
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
          icon: const Icon(LucideIcons.download, size: 18),
          label: const Text('Descargar'),
          onPressed: () => Navigator.pop(ctx, true),
        ),
      ],
    ),
  );
  if (descargar != true || !context.mounted) return;

  SharedPreferences.getInstance().then((p) => p.setString('ota_attempted_version', kAppVersion));

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

Future<void> _mostrarCrearFranquicia(BuildContext context) async {
  final codigoCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final direccionCtrl = TextEditingController();
  final telefonoCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Agregar franquicia'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codigoCtrl, decoration: const InputDecoration(labelText: 'Código (p.ej. 2000)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre (p.ej. Nueva Sede)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: direccionCtrl, decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: telefonoCtrl, decoration: const InputDecoration(labelText: 'Teléfono/WhatsApp', border: OutlineInputBorder())),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(ctx);
            if (codigoCtrl.text.trim().isEmpty || nombreCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Código y nombre son obligatorios'), behavior: SnackBarBehavior.floating));
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregando franquicia...'), behavior: SnackBarBehavior.floating));
            try {
              await FunctionsService.crearFranquicia(
                codigo: codigoCtrl.text.trim(),
                nombre: nombreCtrl.text.trim(),
                direccion: direccionCtrl.text.trim().isEmpty ? null : direccionCtrl.text.trim(),
                telefonoContacto: telefonoCtrl.text.trim().isEmpty ? null : telefonoCtrl.text.trim(),
              );
              AuditLogger().registrar(
                categoria: 'franquicias',
                accion: 'crear',
                coleccion: 'franquicias',
                documentoId: codigoCtrl.text.trim(),
                usuarioId: context.read<AuthProvider>().user?.uid ?? '',
                usuarioNombre: context.read<AuthProvider>().nombreUsuario ?? 'Desarrollador',
                detalles: 'Franquicia "${nombreCtrl.text.trim()}" creada desde config',
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Franquicia ${codigoCtrl.text} agregada'), behavior: SnackBarBehavior.floating));
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
              }
            }
          },
          child: const Text('Agregar'),
        ),
      ],
    ),
  );
}

Future<void> _mostrarCrearProfesional(BuildContext context) async {
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  final nombreCtrl = TextEditingController();
  final documentoCtrl = TextEditingController();

  final restService = FirestoreRestService();
  List<Map<String, dynamic>> franquicias = [];
  try {
    franquicias = await restService.getTodasFranquicias();
  } catch (_) {}

  String? franquiciaSeleccionada = franquicias.isNotEmpty ? franquicias.first['codigo'] as String? : null;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: const Text('Agregar profesional'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre completo', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (acceso a la app)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: passwordCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña (mín. 6 caracteres)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: documentoCtrl, decoration: const InputDecoration(labelText: 'Documento (opcional)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: franquiciaSeleccionada,
                decoration: const InputDecoration(labelText: 'Franquicia', border: OutlineInputBorder()),
                items: franquicias.map((f) {
                  final cod = f['codigo'] as String? ?? '';
                  final nom = f['nombre'] as String? ?? '';
                  return DropdownMenuItem(value: cod, child: Text('$cod - $nom'));
                }).toList(),
                onChanged: (v) => setDialogState(() => franquiciaSeleccionada = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (emailCtrl.text.trim().isEmpty || passwordCtrl.text.trim().isEmpty ||
                  nombreCtrl.text.trim().isEmpty || franquiciaSeleccionada == null) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email, contraseña, nombre y franquicia son obligatorios'), behavior: SnackBarBehavior.floating));
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Agregando profesional...'), behavior: SnackBarBehavior.floating));
              try {
                final result = await FunctionsService.crearProfesional(
                  email: emailCtrl.text.trim(),
                  password: passwordCtrl.text.trim(),
                  nombre: nombreCtrl.text.trim(),
                  documento: documentoCtrl.text.trim().isEmpty ? null : documentoCtrl.text.trim(),
                  franquiciaId: franquiciaSeleccionada!,
                );
                AuditLogger().registrar(
                  categoria: 'profesionales',
                  accion: 'crear',
                  coleccion: 'profesionales',
                  usuarioId: context.read<AuthProvider>().user?.uid ?? '',
                  usuarioNombre: context.read<AuthProvider>().nombreUsuario ?? 'Desarrollador',
                  detalles: 'Profesional "${nombreCtrl.text.trim()}" creado (${emailCtrl.text.trim()})',
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Profesional agregado: ${emailCtrl.text.trim()} → UID ${result['uid']}'),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 4),
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), behavior: SnackBarBehavior.floating));
                }
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _mostrarGestionarFranquicias(BuildContext context) async {
  final restService = FirestoreRestService();
  List<Map<String, dynamic>> franquicias = [];
  List<Map<String, dynamic>> profesionales = [];
  try {
    final results = await Future.wait([
      restService.getTodasFranquicias(),
      restService.getTodosProfesionales(),
    ]);
    franquicias = results[0] as List<Map<String, dynamic>>;
    profesionales = results[1] as List<Map<String, dynamic>>;
  } catch (_) {}

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Gestionar franquicias'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Franquicias', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  FilledButton.tonalIcon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Agregar'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _mostrarCrearFranquicia(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (franquicias.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('No hay franquicias registradas', style: TextStyle(color: Colors.grey)))
              else
                ...franquicias.map((f) {
                  final cod = f['codigo'] as String? ?? '';
                  final nom = f['nombre'] as String? ?? '';
                  final dir = f['direccion'] as String? ?? '';
                  final tel = f['telefonoContacto'] as String? ?? '';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.deepPurple.shade100, child: Text(cod, style: const TextStyle(fontWeight: FontWeight.bold))),
                      title: Text(nom),
                      subtitle: Text([if (dir.isNotEmpty) dir, if (tel.isNotEmpty) tel].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Profesionales', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  FilledButton.tonalIcon(
                    icon: const Icon(LucideIcons.plus, size: 18),
                    label: const Text('Agregar'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _mostrarCrearProfesional(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (profesionales.isEmpty)
                const Padding(padding: EdgeInsets.all(8), child: Text('No hay profesionales activos', style: TextStyle(color: Colors.grey)))
              else
                ...profesionales.map((p) {
                  final nombre = p['nombre'] as String? ?? p['email'] as String? ?? '';
                  final email = p['email'] as String? ?? '';
                  final fid = p['franquiciaId'] as String? ?? '';
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.green.shade100, child: Icon(LucideIcons.user, size: 20, color: Colors.green.shade700)),
                      title: Text(nombre),
                      subtitle: Text('$email · Franquicia $fid', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
      ],
    ),
  );
}

Future<void> _mostrarSelectorFranquicia(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final franchises = await FirestoreRestService().getTodasFranquicias();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.building, size: 20, color: Colors.deepPurple),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Selecciona la franquicia a visualizar',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (franchises.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No hay franquicias registradas', style: TextStyle(color: Colors.grey)),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: franchises.map((f) {
                  final cod = f['codigo'] as String? ?? '';
                  final nom = f['nombre'] as String? ?? '';
                  final dir = f['direccion'] as String? ?? '';
                  final isSelected = auth.franquiciaId == cod;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isSelected ? Colors.deepPurple : Colors.deepPurple.withAlpha(30),
                      child: Text(cod, style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : Colors.deepPurple,
                      )),
                    ),
                    title: Text(nom, style: TextStyle(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    )),
                    subtitle: dir.isNotEmpty ? Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    trailing: isSelected
                        ? const Icon(LucideIcons.check, color: Colors.deepPurple)
                        : const Icon(LucideIcons.chevronRight),
                    onTap: isSelected
                        ? null
                        : () async {
                            Navigator.pop(ctx);
                            await auth.switchFranquicia(cod, nom);
                            if (context.mounted) {
                              final uid = auth.user?.uid;
                              if (uid != null) {
                                context.read<ConfigProvider>().inicializar(uid);
                                context.read<AgendaProvider>().inicializar(uid, nombre: auth.nombreUsuario);
                                context.read<NotificacionProvider>().inicializar(uid);
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Cambiando a franquicia: $nom'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.deepPurple,
                                ),
                              );
                            }
                          },
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 16),
        ],
      ),
    ),
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
            const Icon(LucideIcons.checkCircle2, color: Colors.green, size: 48),
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
            const Icon(LucideIcons.alertCircle, color: Colors.red, size: 48),
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
  final uris = [
    Uri.parse('whatsapp://send?text=$mensaje'),
    Uri.parse('https://wa.me/?text=$mensaje'),
  ];
  for (final uri in uris) {
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
  }
  try {
    await launchUrl(uris[1], mode: LaunchMode.platformDefault);
  } catch (_) {
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
