import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
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
  final _picker = ImagePicker();
  final _uuid = const Uuid();
  late TextEditingController _nombresCtrl;
  late TextEditingController _docCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _emailCtrl;
  bool _editando = false;
  bool _guardando = false;
  bool _eliminando = false;
  bool _subiendoFoto = false;
  String? _fotoUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.paciente;
    _nombresCtrl = TextEditingController(text: p.nombres);
    _docCtrl = TextEditingController(text: p.documento);
    _telCtrl = TextEditingController(text: p.telefono);
    _emailCtrl = TextEditingController(text: p.email ?? '');
    _fotoUrl = p.fotoUrl;
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
      fotoUrl: _fotoUrl,
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

  void _mostrarSelectorFoto() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Tomar foto'),
              onTap: () {
                Navigator.pop(ctx);
                _tomarFoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Elegir de la galería'),
              onTap: () {
                Navigator.pop(ctx);
                _tomarFoto(ImageSource.gallery);
              },
            ),
            if (_fotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Eliminar foto', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _eliminarFoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _tomarFoto(ImageSource source) async {
    final file = await _picker.pickImage(source: source, maxWidth: 512, maxHeight: 512);
    if (file == null) return;

    setState(() => _subiendoFoto = true);
    try {
      final path = 'pacientes/${widget.paciente.id}/${_uuid.v4()}.jpg';
      final ref = FirebaseStorage.instance.ref().child(path);
      final bytes = await file.readAsBytes();
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      final actualizado = widget.paciente.copyWith(fotoUrl: url);
      await _service.updatePaciente(actualizado);

      setState(() {
        _fotoUrl = url;
        _subiendoFoto = false;
      });
      widget.onActualizado?.call();
    } catch (e) {
      setState(() => _subiendoFoto = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir foto: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _eliminarFoto() async {
    setState(() => _subiendoFoto = true);
    try {
      final actualizado = widget.paciente.copyWith(fotoUrl: null);
      await _service.updatePaciente(actualizado);
      setState(() {
        _fotoUrl = null;
        _subiendoFoto = false;
      });
      widget.onActualizado?.call();
    } catch (e) {
      setState(() => _subiendoFoto = false);
    }
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
          GestureDetector(
            onTap: _subiendoFoto ? null : _mostrarSelectorFoto,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.blue.shade100,
                  backgroundImage: _fotoUrl != null ? NetworkImage(_fotoUrl!) : null,
                  child: _fotoUrl == null
                      ? Text(_iniciales, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))
                      : null,
                ),
                if (_subiendoFoto)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: _subiendoFoto ? null : _mostrarSelectorFoto,
            child: Text(
              _fotoUrl != null ? 'Cambiar foto' : 'Agregar foto',
              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12, decoration: TextDecoration.underline),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(p.nombres, style: theme.textTheme.titleLarge),
          ),
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
        if (p.telefono.isNotEmpty)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _actionBtn(Icons.phone, 'Llamar', p.telefono.isNotEmpty ? _llamar : null),
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

  Widget _actionBtn(IconData icon, String label, VoidCallback? onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        foregroundColor: onTap != null ? null : Colors.grey,
        backgroundColor: onTap != null ? null : Colors.grey.shade100,
        disabledForegroundColor: Colors.grey,
        disabledBackgroundColor: Colors.grey.shade100,
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
