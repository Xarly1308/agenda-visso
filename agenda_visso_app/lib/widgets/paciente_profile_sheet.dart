import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/paciente.dart';
import '../services/firestore_service.dart';

class PacienteProfileSheet extends StatefulWidget {
  final Paciente paciente;
  final VoidCallback? onActualizado;

  const PacienteProfileSheet({super.key, required this.paciente, this.onActualizado});

  @override
  State<PacienteProfileSheet> createState() => _PacienteProfileSheetState();
}

class _PacienteProfileSheetState extends State<PacienteProfileSheet> {
  final _service = FirestoreService();
  late TextEditingController _nombresCtrl;
  late TextEditingController _docCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _emailCtrl;
  bool _editando = false;
  bool _guardando = false;
  bool _eliminando = false;

  @override
  void initState() {
    super.initState();
    final p = widget.paciente;
    _nombresCtrl = TextEditingController(text: p.nombres);
    _docCtrl = TextEditingController(text: p.documento);
    _telCtrl = TextEditingController(text: p.telefono);
    _emailCtrl = TextEditingController(text: p.email ?? '');
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _docCtrl.dispose();
    _telCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final actualizado = widget.paciente.copyWith(
      nombres: _nombresCtrl.text.trim(),
      documento: _docCtrl.text.trim(),
      telefono: _telCtrl.text.trim(),
      email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
    );
    await _service.updatePaciente(actualizado);
    setState(() {
      _guardando = false;
      _editando = false;
    });
    widget.onActualizado?.call();
  }

  Future<void> _eliminar() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar paciente'),
        content: Text('¿Eliminar a "${widget.paciente.nombres}" definitivamente? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    setState(() => _eliminando = true);
    try {
      await _service.deletePaciente(widget.paciente.id);
      if (mounted) Navigator.pop(context);
      widget.onActualizado?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _eliminando = false);
    }
  }

  void _llamar() async {
    final tel = widget.paciente.telefono;
    if (tel.isEmpty) return;
    final uri = Uri.parse('tel:$tel');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _enviarCorreo() async {
    final email = widget.paciente.email;
    if (email == null || email.isEmpty) return;
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  String get _iniciales {
    final nombres = widget.paciente.nombres;
    if (nombres.isEmpty) return '?';
    return nombres.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.paciente;
    final theme = Theme.of(context);

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 16;
    return Padding(
      padding: EdgeInsets.only(
        bottom: bottomPadding,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          handle(),
          const SizedBox(height: 12),
          CircleAvatar(radius: 36, backgroundColor: Colors.blue.shade100,
              child: Text(_iniciales, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))),
          const SizedBox(height: 8),
          Text(p.nombres, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Doc: ${p.documento}', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          if (_editando) _buildEditForm() else _buildInfo(),
        ],
      ),
    );
  }

  Widget handle() {
    return Container(width: 40, height: 4, decoration: BoxDecoration(
      color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
    ));
  }

  Widget _buildInfo() {
    final p = widget.paciente;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (p.telefono.isNotEmpty || (p.email != null && p.email!.isNotEmpty))
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (p.telefono.isNotEmpty)
                _actionBtn(Icons.phone, 'Llamar', _llamar),
              if (p.telefono.isNotEmpty && (p.email != null && p.email!.isNotEmpty))
                const SizedBox(width: 12),
              if (p.email != null && p.email!.isNotEmpty)
                _actionBtn(Icons.email, 'Correo', _enviarCorreo),
            ],
          ),
        const SizedBox(height: 16),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('Editar datos'),
          onPressed: () => setState(() => _editando = true),
        )),
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          icon: _eliminando
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.delete_outline, size: 18),
          label: Text(_eliminando ? 'Eliminando...' : 'Eliminar paciente'),
          onPressed: _eliminando ? null : _eliminar,
        )),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(controller: _nombresCtrl, decoration: const InputDecoration(labelText: 'Nombres', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _docCtrl, decoration: const InputDecoration(labelText: 'Documento', border: OutlineInputBorder()),
            validator: (v) => v?.trim().isEmpty ?? true ? 'Requerido' : null),
        const SizedBox(height: 12),
        TextFormField(controller: _telCtrl, decoration: const InputDecoration(labelText: 'Teléfono', border: OutlineInputBorder()),
            keyboardType: TextInputType.phone),
        const SizedBox(height: 12),
        TextFormField(controller: _emailCtrl, decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: OutlinedButton(
              onPressed: () {
                final p = widget.paciente;
                _nombresCtrl.text = p.nombres;
                _docCtrl.text = p.documento;
                _telCtrl.text = p.telefono;
                _emailCtrl.text = p.email ?? '';
                setState(() => _editando = false);
              },
              child: const Text('Cancelar'),
            )),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(
              onPressed: _guardando ? null : _guardar,
              child: _guardando ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            )),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
