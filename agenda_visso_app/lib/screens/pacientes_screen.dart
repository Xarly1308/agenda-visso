import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pacientes_provider.dart';
import '../models/paciente.dart';
import '../widgets/paciente_profile_sheet.dart';
import 'nueva_cita_screen.dart';

class PacientesScreen extends StatefulWidget {
  const PacientesScreen({super.key});

  @override
  State<PacientesScreen> createState() => _PacientesScreenState();
}

class _PacientesScreenState extends State<PacientesScreen> {
  final _searchCtrl = TextEditingController();
  bool _inicializado = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_inicializado) {
      _inicializado = true;
      context.read<PacientesProvider>().cargarTodos();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _nuevaCita(Paciente p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NuevaCitaScreen(pacienteInicial: p),
      ),
    );
  }

  void _mostrarPerfil(Paciente p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PacienteProfileSheet(
        paciente: p,
        onActualizado: () {
          context.read<PacientesProvider>().cargarTodos();
        },
      ),
    );
  }

  String _labelSort(SortMode m) {
    switch (m) {
      case SortMode.masReciente: return 'Más recientes';
      case SortMode.masAntiguo: return 'Más antiguos';
      case SortMode.alfabeticoAZ: return 'A-Z';
      case SortMode.alfabeticoZA: return 'Z-A';
    }
  }

  IconData _iconSort(SortMode m) {
    switch (m) {
      case SortMode.masReciente: return Icons.access_time;
      case SortMode.masAntiguo: return Icons.access_time;
      case SortMode.alfabeticoAZ: return Icons.sort_by_alpha;
      case SortMode.alfabeticoZA: return Icons.sort_by_alpha;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PacientesProvider>();
    final pacientes = provider.resultados;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o documento',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              provider.buscar('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (v) => provider.buscar(v),
                ),
              ),
              PopupMenuButton<SortMode>(
                icon: Icon(_iconSort(provider.sortMode)),
                tooltip: 'Ordenar',
                onSelected: provider.cambiarSortMode,
                itemBuilder: (_) => SortMode.values.map((m) =>
                  PopupMenuItem(
                    value: m,
                    child: Row(
                      children: [
                        Icon(m == provider.sortMode ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            size: 18),
                        const SizedBox(width: 8),
                        Text(_labelSort(m)),
                      ],
                    ),
                  ),
                ).toList(),
              ),
            ],
          ),
        ),
        if (provider.cargando)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (pacientes.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                _searchCtrl.text.isNotEmpty
                    ? 'No se encontraron pacientes'
                    : 'No hay pacientes registrados',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          Expanded(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    children: [
                      Text('${pacientes.length} paciente${pacientes.length == 1 ? '' : 's'}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                      const Spacer(),
                      Text(_labelSort(provider.sortMode),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: pacientes.length,
                    itemBuilder: (_, i) {
                      final p = pacientes[i];
                      final iniciales = p.nombres.isNotEmpty
                          ? p.nombres.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
                          : '?';
                      String? subtitulo;
                      if (p.telefono.isNotEmpty) {
                        subtitulo = 'Doc: ${p.documento} | Tel: ${p.telefono}';
                      } else {
                        subtitulo = 'Doc: ${p.documento}';
                      }
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Text(iniciales,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          title: Text(p.nombres,
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(subtitulo),
                          onTap: () => _mostrarPerfil(p),
                          trailing: FilledButton.tonalIcon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Nueva cita'),
                            onPressed: () => _nuevaCita(p),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
