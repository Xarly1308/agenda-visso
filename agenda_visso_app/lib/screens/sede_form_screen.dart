import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/sede.dart';
import '../providers/config_provider.dart';

class SedeFormScreen extends StatefulWidget {
  final Sede? sede;
  const SedeFormScreen({super.key, this.sede});

  @override
  State<SedeFormScreen> createState() => _SedeFormScreenState();
}

class _SedeFormScreenState extends State<SedeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombreCtrl;
  late final TextEditingController _direccionCtrl;
  late final TextEditingController _telefonoCtrl;
  bool _editando = false;
  String _iconoSeleccionado = 'store';

  static const _iconosDisponibles = [
    'store',
    'medical_services',
    'visibility',
    'local_hospital',
    'home',
    'business',
    'location_city',
    'apartment',
  ];

  static IconData _iconoDeSede(String icono) {
    switch (icono) {
      case 'store': return LucideIcons.store;
      case 'medical_services': return LucideIcons.heartPulse;
      case 'visibility': return LucideIcons.eye;
      case 'local_hospital': return LucideIcons.stethoscope;
      case 'home': return LucideIcons.home;
      case 'business': return LucideIcons.building2;
      case 'location_city': return LucideIcons.building2;
      case 'apartment': return LucideIcons.building;
      default: return LucideIcons.store;
    }
  }

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.sede?.nombre ?? '');
    _direccionCtrl = TextEditingController(text: widget.sede?.direccion ?? '');
    _telefonoCtrl = TextEditingController(text: widget.sede?.telefono ?? '');
    _editando = widget.sede != null;
    _iconoSeleccionado = widget.sede?.icono ?? 'store';
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _direccionCtrl.dispose();
    _telefonoCtrl.dispose();
    super.dispose();
  }

  String? _validarRequerido(String? v, String label) {
    if (v?.trim().isEmpty ?? true) return '$label es requerido';
    return null;
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    final config = context.read<ConfigProvider>();
    final data = Sede(
      id: widget.sede?.id ?? '',
      nombre: _nombreCtrl.text.trim(),
      direccion: _direccionCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim().isEmpty ? null : _telefonoCtrl.text.trim(),
      activa: widget.sede?.activa ?? true,
      icono: _iconoSeleccionado,
    );

    if (_editando) {
      await config.actualizarSede(data);
    } else {
      await config.agregarSede(data);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar sede' : 'Nueva sede')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre', border: OutlineInputBorder()),
                validator: (v) => _validarRequerido(v, 'Nombre'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccionCtrl,
                decoration: const InputDecoration(labelText: 'Dirección', border: OutlineInputBorder()),
                validator: (v) => _validarRequerido(v, 'Dirección'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Teléfono de contacto',
                  border: OutlineInputBorder(),
                  hintText: 'Opcional',
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 24),
              Text('Icono de la sede:', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _iconosDisponibles.map((valor) {
                  final seleccionado = _iconoSeleccionado == valor;
                  final primary = Theme.of(context).colorScheme.primary;
                final primaryLight = primary.withAlpha(13);
                return GestureDetector(
                    onTap: () => setState(() => _iconoSeleccionado = valor),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: seleccionado ? primaryLight : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: seleccionado ? primary : Colors.grey.shade300,
                          width: seleccionado ? 2 : 1,
                        ),
                      ),
                      child: Icon(
                        _iconoDeSede(valor),
                        color: seleccionado ? primary : Colors.grey.shade600,
                        size: 28,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _guardar,
                  child: Text(_editando ? 'Actualizar' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
