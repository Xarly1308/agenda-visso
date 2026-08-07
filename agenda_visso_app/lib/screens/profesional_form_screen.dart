import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/firestore_rest_service.dart';
import '../services/functions_service.dart';
import '../utils/audit_logger.dart';

class ProfesionalFormScreen extends StatefulWidget {
  final Map<String, dynamic>? profesional;

  const ProfesionalFormScreen({super.key, this.profesional});

  @override
  State<ProfesionalFormScreen> createState() => _ProfesionalFormScreenState();
}

class _ProfesionalFormScreenState extends State<ProfesionalFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rest = FirestoreRestService();

  late TextEditingController _nombreCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _passwordCtrl;
  late TextEditingController _documentoCtrl;

  List<Map<String, dynamic>> _franquicias = [];
  String? _franquiciaSeleccionada;
  bool _guardando = false;
  bool _cargandoFranquicias = true;

  bool get _esEdicion => widget.profesional != null;

  @override
  void initState() {
    super.initState();
    final p = widget.profesional;
    _nombreCtrl = TextEditingController(text: p?['nombre'] as String? ?? '');
    _emailCtrl = TextEditingController(text: p?['email'] as String? ?? '');
    _passwordCtrl = TextEditingController();
    _documentoCtrl = TextEditingController(text: p?['documento'] as String? ?? '');
    _franquiciaSeleccionada = p?['franquiciaId'] as String?;
    _cargarFranquicias();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _documentoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarFranquicias() async {
    try {
      final f = await _rest.getTodasFranquicias();
      if (mounted) {
        setState(() {
          _franquicias = f;
          if (_franquiciaSeleccionada == null && f.isNotEmpty) {
            _franquiciaSeleccionada = f.first['codigo'] as String?;
          }
          _cargandoFranquicias = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoFranquicias = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_franquiciaSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una franquicia')),
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        final updates = <String, dynamic>{
          'nombre': _nombreCtrl.text.trim(),
        };
        if (_emailCtrl.text.trim() != (widget.profesional?['email'] as String? ?? '')) {
          updates['email'] = _emailCtrl.text.trim();
        }
        if (_passwordCtrl.text.isNotEmpty) {
          updates['password'] = _passwordCtrl.text.trim();
        }
        if (_documentoCtrl.text.trim() != (widget.profesional?['documento'] as String? ?? '')) {
          updates['documento'] = _documentoCtrl.text.trim();
        }
        if (_franquiciaSeleccionada != (widget.profesional?['franquiciaId'] as String? ?? '')) {
          updates['franquiciaId'] = _franquiciaSeleccionada!;
        }
        if (updates.length > 1 || !updates.containsKey('email')) {
          await FunctionsService.editarProfesional(
            uid: widget.profesional!['id'] as String,
            nombre: updates['nombre'] as String,
            email: updates.containsKey('email') ? updates['email'] as String : null,
            password: updates['password'] as String?,
            documento: updates['documento'] as String?,
            franquiciaId: updates['franquiciaId'] as String?,
          );
        } else {
          await FunctionsService.editarProfesional(
            uid: widget.profesional!['id'] as String,
            nombre: updates['nombre'] as String,
          );
        }
        AuditLogger().registrar(
          categoria: 'profesionales',
          accion: 'editar',
          coleccion: 'profesionales',
          documentoId: widget.profesional!['id'] as String,
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Profesional "${updates['nombre']}" actualizado',
        );
      } else {
        await FunctionsService.crearProfesional(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text.trim(),
          nombre: _nombreCtrl.text.trim(),
          documento: _documentoCtrl.text.trim().isEmpty ? null : _documentoCtrl.text.trim(),
          franquiciaId: _franquiciaSeleccionada!,
        );
        AuditLogger().registrar(
          categoria: 'profesionales',
          accion: 'crear',
          coleccion: 'profesionales',
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Profesional "${_nombreCtrl.text.trim()}" creado (${_emailCtrl.text.trim()})',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_esEdicion ? 'Profesional actualizado' : 'Profesional creado')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardando = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar profesional' : 'Agregar profesional'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre completo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.user),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email (acceso a la app)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.mail),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || v.trim().isEmpty ? 'El email es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: _esEdicion ? 'Nueva contraseña (dejar vacío para no cambiar)' : 'Contraseña (mín. 6 caracteres)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(LucideIcons.lock),
                ),
                validator: (v) {
                  if (!_esEdicion && (v == null || v.trim().isEmpty)) return 'La contraseña es obligatoria';
                  if (v != null && v.isNotEmpty && v.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _documentoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Documento (opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.creditCard),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              _cargandoFranquicias
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<String>(
                      value: _franquiciaSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Franquicia',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(LucideIcons.building),
                      ),
                      items: _franquicias.map((f) {
                        final cod = f['codigo'] as String? ?? '';
                        final nom = f['nombre'] as String? ?? '';
                        return DropdownMenuItem(value: cod, child: Text('$cod - $nom'));
                      }).toList(),
                      onChanged: (v) => setState(() => _franquiciaSeleccionada = v),
                      validator: (v) => v == null || v.isEmpty ? 'Selecciona una franquicia' : null,
                    ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _guardando ? null : _guardar,
                icon: _guardando
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.check, size: 20),
                label: Text(_guardando ? 'Guardando...' : 'Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
