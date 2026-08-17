import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../providers/pacientes_provider.dart';
import '../models/cita.dart';
import '../models/paciente.dart';
import '../utils/formato_hora.dart';
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
  int _paginaActual = 0;
  static const int _porPagina = 10;

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
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
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

  Widget _infoRow(IconData icon, String text, {bool isTitle = false}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade500),
        const SizedBox(width: 6),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              style: TextStyle(
                fontSize: isTitle ? 16 : 14,
                fontWeight: isTitle ? FontWeight.w600 : FontWeight.normal,
                color: isTitle ? Colors.black87 : Colors.grey.shade700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PacientesProvider>();
    final pacientes = provider.resultados;
    final totalPaginas = (pacientes.length / _porPagina).ceil();
    if (_paginaActual >= totalPaginas && totalPaginas > 0) _paginaActual = totalPaginas - 1;
    final inicio = _paginaActual * _porPagina;
    final fin = (inicio + _porPagina).clamp(0, pacientes.length);
    final pacientesPagina = pacientes.sublist(inicio, fin);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          child: Row(
            children: [
              SizedBox(
                width: 400,
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
                              setState(() => _paginaActual = 0);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                  ),
                  onChanged: (v) {
                    provider.buscar(v);
                    setState(() => _paginaActual = 0);
                  },
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
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
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
                  child: kIsWeb ? _buildWebGrid(pacientesPagina, provider) : _buildMobileList(pacientesPagina),
                ),
                if (totalPaginas > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: _paginaActual > 0
                              ? () => setState(() => _paginaActual--)
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Página ${_paginaActual + 1} de $totalPaginas',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: _paginaActual < totalPaginas - 1
                              ? () => setState(() => _paginaActual++)
                              : null,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildWebGrid(List<Paciente> pacientesPagina, PacientesProvider provider) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      itemCount: pacientesPagina.length,
      itemBuilder: (_, i) => _buildPacienteCardWeb(pacientesPagina[i], provider),
    );
  }

  Widget _buildPacienteCardWeb(Paciente p, PacientesProvider provider) {
    final iniciales = p.nombres.isNotEmpty
        ? p.nombres.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
        : '?';
    final ultimaCita = provider.getUltimaCita(p.id);
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: p.fotoUrl != null ? NetworkImage(p.fotoUrl!) : null,
              child: p.fotoUrl == null
                  ? Text(iniciales, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(p.nombres,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text('Doc: ${p.documento}  ·  Tel: ${p.telefono}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(LucideIcons.pencil, size: 14),
                        label: const Text('Editar'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 34),
                        ),
                        onPressed: () => _mostrarPerfil(p),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        icon: const Icon(LucideIcons.plus, size: 14),
                        label: const Text('Nueva cita'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 34),
                        ),
                        onPressed: () => _nuevaCita(p),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 1,
              height: 50,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: Colors.grey.shade300,
            ),
            SizedBox(
              width: 160,
              child: ultimaCita != null ? _buildUltimaCitaInfo(ultimaCita) : _buildSinCitas(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUltimaCitaInfo(Cita cita) {
    final estado = cita.estado;
    final colorEstado = estado == 'confirmada'
        ? Colors.green
        : estado == 'cancelada'
            ? Colors.red
            : Colors.orange;
    final meses = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    final fechaStr = '${cita.fecha.day} ${meses[cita.fecha.month - 1]}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Última cita', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('$fechaStr · ${formato12h(cita.hora)}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(cita.tipoConsulta ?? 'General',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: colorEstado.withAlpha(25),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(estado[0].toUpperCase() + estado.substring(1),
              style: TextStyle(fontSize: 11, color: colorEstado, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildSinCitas() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Última cita', style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('Sin citas', style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildMobileList(List<Paciente> pacientesPagina) {
    return ListView.builder(
      itemCount: pacientesPagina.length,
      itemBuilder: (_, i) {
        final p = pacientesPagina[i];
        final iniciales = p.nombres.isNotEmpty
            ? p.nombres.split(' ').where((w) => w.isNotEmpty).map((w) => w[0]).take(2).join()
            : '?';
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _infoRow(Icons.person_outline, p.nombres, isTitle: true),
                          const SizedBox(height: 4),
                          _infoRow(Icons.badge_outlined, 'Doc: ${p.documento}'),
                          const SizedBox(height: 2),
                          _infoRow(Icons.phone_outlined, 'Tel: ${p.telefono}'),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.blue.shade100,
                      backgroundImage: p.fotoUrl != null ? NetworkImage(p.fotoUrl!) : null,
                      child: p.fotoUrl == null
                          ? Text(iniciales,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(LucideIcons.pencil, size: 18),
                        label: const Text('Editar datos'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => _mostrarPerfil(p),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Nueva cita'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: const Size(0, 36),
                        ),
                        onPressed: () => _nuevaCita(p),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
