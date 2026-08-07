import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/firestore_rest_service.dart';
import '../services/functions_service.dart';
import '../utils/audit_logger.dart';

class FranquiciaFormScreen extends StatefulWidget {
  final Map<String, dynamic>? franquicia;

  const FranquiciaFormScreen({super.key, this.franquicia});

  @override
  State<FranquiciaFormScreen> createState() => _FranquiciaFormScreenState();
}

class _FranquiciaFormScreenState extends State<FranquiciaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _rest = FirestoreRestService();

  late TextEditingController _codigoCtrl;
  late TextEditingController _nombreCtrl;
  late TextEditingController _direccionCtrl;
  late TextEditingController _telefonoCtrl;
  bool _guardando = false;

  bool get _esEdicion => widget.franquicia != null;

  @override
  void initState() {
    super.initState();
    final f = widget.franquicia;
    _codigoCtrl = TextEditingController(text: f?['codigo'] as String? ?? '');
    _nombreCtrl = TextEditingController(text: f?['nombre'] as String? ?? '');
    _direccionCtrl = TextEditingController(text: f?['direccion'] as String? ?? '');
    _telefonoCtrl = TextEditingController(text: f?['telefonoContacto'] as String? ?? '');
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _guardando = true);
    try {
      if (_esEdicion) {
        final data = {
          'nombre': _nombreCtrl.text.trim(),
          'direccion': _direccionCtrl.text.trim(),
          'telefonoContacto': _telefonoCtrl.text.trim(),
        };
        await _rest.updateFranquicia(_codigoCtrl.text.trim(), data);
        AuditLogger().registrar(
          categoria: 'franquicias',
          accion: 'editar',
          coleccion: 'franquicias',
          documentoId: _codigoCtrl.text.trim(),
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Franquicia "${_nombreCtrl.text.trim()}" actualizada',
        );
      } else {
        await FunctionsService.crearFranquicia(
          codigo: _codigoCtrl.text.trim(),
          nombre: _nombreCtrl.text.trim(),
          direccion: _direccionCtrl.text.trim(),
          telefonoContacto: _telefonoCtrl.text.trim(),
        );
        AuditLogger().registrar(
          categoria: 'franquicias',
          accion: 'crear',
          coleccion: 'franquicias',
          documentoId: _codigoCtrl.text.trim(),
          usuarioId: '',
          usuarioNombre: 'Desarrollador',
          detalles: 'Franquicia "${_nombreCtrl.text.trim()}" creada',
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_esEdicion ? 'Franquicia actualizada' : 'Franquicia creada')),
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
        title: Text(_esEdicion ? 'Editar franquicia' : 'Agregar franquicia'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _codigoCtrl,
                enabled: !_esEdicion,
                decoration: const InputDecoration(
                  labelText: 'Código (p.ej. 2000)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.hash),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'El código es obligatorio';
                  if (_esEdicion) return null;
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.building),
                ),
                validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es obligatorio' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.mapPin),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono / WhatsApp',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(LucideIcons.phone),
                ),
                keyboardType: TextInputType.phone,
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
