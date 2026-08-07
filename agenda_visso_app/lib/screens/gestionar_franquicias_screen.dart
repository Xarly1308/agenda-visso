import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/firestore_rest_service.dart';
import '../services/functions_service.dart';
import '../utils/audit_logger.dart';
import 'franquicia_form_screen.dart';
import 'profesional_form_screen.dart';

class GestionarFranquiciasScreen extends StatefulWidget {
  const GestionarFranquiciasScreen({super.key});

  @override
  State<GestionarFranquiciasScreen> createState() => _GestionarFranquiciasScreenState();
}

class _GestionarFranquiciasScreenState extends State<GestionarFranquiciasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirestoreRestService _rest = FirestoreRestService();

  // Franquicias
  List<Map<String, dynamic>> _franquicias = [];
  List<Map<String, dynamic>> _franquiciasFiltradas = [];
  bool _cargandoFranquicias = true;
  String _queryFranquicias = '';

  // Profesionales
  List<Map<String, dynamic>> _profesionales = [];
  List<Map<String, dynamic>> _profesionalesFiltrados = [];
  bool _cargandoProfesionales = true;
  String _queryProfesionales = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _cargarDatos();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargandoFranquicias = true;
      _cargandoProfesionales = true;
    });
    try {
      final results = await Future.wait([
        _rest.getTodasFranquicias(),
        _rest.getTodosProfesionales(),
      ]);
      if (mounted) {
        setState(() {
          _franquicias = results[0] as List<Map<String, dynamic>>;
          _franquiciasFiltradas = _franquicias;
          _cargandoFranquicias = false;
          _profesionales = results[1] as List<Map<String, dynamic>>;
          _profesionalesFiltrados = _profesionales;
          _cargandoProfesionales = false;
        });
      }
    } catch (e) {
      debugPrint('Error cargando datos gestor: $e');
      if (mounted) {
        setState(() {
          _cargandoFranquicias = false;
          _cargandoProfesionales = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: ${e.toString().length > 120 ? '${e.toString().substring(0, 120)}...' : e.toString()}'),
            backgroundColor: Colors.red.shade700,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _filtrarFranquicias(String query) {
    setState(() {
      _queryFranquicias = query;
      if (query.isEmpty) {
        _franquiciasFiltradas = _franquicias;
      } else {
        final q = query.toLowerCase();
        _franquiciasFiltradas = _franquicias.where((f) {
          final cod = (f['codigo'] as String? ?? '').toLowerCase();
          final nom = (f['nombre'] as String? ?? '').toLowerCase();
          return cod.contains(q) || nom.contains(q);
        }).toList();
      }
    });
  }

  void _filtrarProfesionales(String query) {
    setState(() {
      _queryProfesionales = query;
      if (query.isEmpty) {
        _profesionalesFiltrados = _profesionales;
      } else {
        final q = query.toLowerCase();
        _profesionalesFiltrados = _profesionales.where((p) {
          final nom = (p['nombre'] as String? ?? '').toLowerCase();
          final ema = (p['email'] as String? ?? '').toLowerCase();
          return nom.contains(q) || ema.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _confirmarEliminarFranquicia(Map<String, dynamic> f) async {
    final cod = f['codigo'] as String? ?? '';
    final nom = f['nombre'] as String? ?? '';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar franquicia'),
        content: Text('¿Eliminar "$nom" ($cod)? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await _rest.deleteFranquicia(cod);
        AuditLogger().registrar(
          categoria: 'franquicias',
          accion: 'eliminar',
          coleccion: 'franquicias',
          documentoId: cod,
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Franquicia "$nom" eliminada',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Franquicia "$nom" eliminada')));
          _cargarDatos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  Future<void> _confirmarEliminarProfesional(Map<String, dynamic> p) async {
    final nom = p['nombre'] as String? ?? p['email'] as String? ?? '';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar profesional'),
        content: Text('¿Eliminar "$nom"? Se eliminará la cuenta de acceso y todos sus datos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmar == true) {
      try {
        await FunctionsService.eliminarProfesional(uid: p['id'] as String);
        AuditLogger().registrar(
          categoria: 'profesionales',
          accion: 'eliminar',
          coleccion: 'profesionales',
          documentoId: p['id'] as String,
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Profesional "$nom" eliminado',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profesional "$nom" eliminado')));
          _cargarDatos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionar franquicias'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(LucideIcons.building), text: 'Franquicias'),
            Tab(icon: Icon(LucideIcons.users), text: 'Profesionales'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final esFranquicias = _tabController.index == 0;
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (_) => esFranquicias
                  ? const FranquiciaFormScreen()
                  : const ProfesionalFormScreen(),
            ),
          );
          if (result == true) _cargarDatos();
        },
        icon: Icon(_tabController.index == 0 ? LucideIcons.plus : LucideIcons.userPlus),
        label: Text(_tabController.index == 0 ? 'Agregar franquicia' : 'Agregar profesional'),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFranquiciasTab(isDesktop),
          _buildProfesionalesTab(isDesktop),
        ],
      ),
    );
  }

  Widget _buildFranquiciasTab(bool isDesktop) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: _filtrarFranquicias,
            decoration: InputDecoration(
              hintText: 'Buscar por código o nombre...',
              prefixIcon: const Icon(LucideIcons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _cargandoFranquicias
              ? const Center(child: CircularProgressIndicator())
              : _franquiciasFiltradas.isEmpty
                  ? Center(child: Text(_queryFranquicias.isEmpty
                      ? 'No hay franquicias registradas'
                      : 'No se encontraron resultados'))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _franquiciasFiltradas.length,
                        itemBuilder: (context, i) {
                          final f = _franquiciasFiltradas[i];
                          final cod = f['codigo'] as String? ?? '';
                          final nom = f['nombre'] as String? ?? '';
                          final dir = f['direccion'] as String? ?? '';
                          final tel = f['telefonoContacto'] as String? ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.deepPurple.shade100,
                                child: Text(cod.length >= 2 ? cod.substring(cod.length - 2) : cod,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  Text(cod, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                              subtitle: dir.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(dir, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 20),
                                color: Colors.red.shade300,
                                onPressed: () => _confirmarEliminarFranquicia(f),
                              ),
                              onTap: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FranquiciaFormScreen(franquicia: f),
                                  ),
                                );
                                if (result == true) _cargarDatos();
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (isDesktop) {
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: body));
    }
    return body;
  }

  Widget _buildProfesionalesTab(bool isDesktop) {
    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: _filtrarProfesionales,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o email...',
              prefixIcon: const Icon(LucideIcons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        Expanded(
          child: _cargandoProfesionales
              ? const Center(child: CircularProgressIndicator())
              : _profesionalesFiltrados.isEmpty
                  ? Center(child: Text(_queryProfesionales.isEmpty
                      ? 'No hay profesionales activos'
                      : 'No se encontraron resultados'))
                  : RefreshIndicator(
                      onRefresh: _cargarDatos,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _profesionalesFiltrados.length,
                        itemBuilder: (context, i) {
                          final p = _profesionalesFiltrados[i];
                          final nom = p['nombre'] as String? ?? '';
                          final email = p['email'] as String? ?? '';
                          final fid = p['franquiciaId'] as String? ?? '';
                          final doc = p['documento'] as String? ?? '';
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.green.shade100,
                                child: Text(
                                  nom.isNotEmpty ? nom[0].toUpperCase() : '?',
                                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (email.isNotEmpty)
                                    Text(email, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                              subtitle: fid.isNotEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('Franquicia $fid', maxLines: 1, overflow: TextOverflow.ellipsis),
                                    )
                                  : null,
                              trailing: IconButton(
                                icon: const Icon(LucideIcons.trash2, size: 20),
                                color: Colors.red.shade300,
                                onPressed: () => _confirmarEliminarProfesional(p),
                              ),
                              onTap: () async {
                                final result = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ProfesionalFormScreen(profesional: p),
                                  ),
                                );
                                if (result == true) _cargarDatos();
                              },
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );

    if (isDesktop) {
      return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: body));
    }
    return body;
  }
}
