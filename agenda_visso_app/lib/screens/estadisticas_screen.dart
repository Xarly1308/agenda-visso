import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key});

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> {
  final _service = FirestoreService();
  bool _cargando = true;
  int _mesSeleccionado = DateTime.now().month;
  int _anioSeleccionado = DateTime.now().year;

  int _totalCitas = 0;
  int _nuevos = 0;
  int _antiguos = 0;
  Map<String, int> _citasPorTipo = {};
  Map<String, int> _citasPorSede = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final inicio = DateTime(_anioSeleccionado, _mesSeleccionado, 1);
      final fin = DateTime(_anioSeleccionado, _mesSeleccionado + 1, 0);

      final pacientes = await _service.getAllPacientes();
      _nuevos = pacientes.where((p) => !p.yaEraPaciente).length;
      _antiguos = pacientes.where((p) => p.yaEraPaciente).length;

      final citas = await _service.getCitasEnRango(inicio, fin);
      _totalCitas = citas.length;

      _citasPorTipo = {};
      for (final c in citas) {
        final tipo = c.tipoConsulta ?? 'Sin especificar';
        _citasPorTipo[tipo] = (_citasPorTipo[tipo] ?? 0) + 1;
      }

      final sedes = await _service.getSedes();
      final mapaSedes = {for (final s in sedes) s.id: s.nombre};
      _citasPorSede = {};
      for (final c in citas) {
        final sede = mapaSedes[c.sedeId] ?? 'Sin sede';
        _citasPorSede[sede] = (_citasPorSede[sede] ?? 0) + 1;
      }
    } catch (_) {}
    if (mounted) setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estadísticas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMesSelector(),
                  const SizedBox(height: 16),
                  _buildPacientesCard(),
                  const SizedBox(height: 12),
                  _buildCitasCard(),
                  const SizedBox(height: 12),
                  _buildPorTipo(),
                  const SizedBox(height: 12),
                  _buildPorSede(),
                ],
              ),
            ),
    );
  }

  Widget _buildMesSelector() {
    final meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
    ];
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              if (_mesSeleccionado == 1) {
                _mesSeleccionado = 12;
                _anioSeleccionado--;
              } else {
                _mesSeleccionado--;
              }
            });
            _cargar();
          },
        ),
        Expanded(
          child: Text(
            '${meses[_mesSeleccionado - 1]} $_anioSeleccionado',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              if (_mesSeleccionado == 12) {
                _mesSeleccionado = 1;
                _anioSeleccionado++;
              } else {
                _mesSeleccionado++;
              }
            });
            _cargar();
          },
        ),
      ],
    );
  }

  Widget _buildPacientesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pacientes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statBox('Nuevos', _nuevos, Colors.green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statBox('Antiguos', _antiguos, Colors.orange),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCitasCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Citas del mes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Center(
              child: Text('$_totalCitas', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.teal)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPorTipo() {
    if (_citasPorTipo.isEmpty) return const SizedBox();
    final total = _citasPorTipo.values.fold(0, (a, b) => a + b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por tipo de consulta', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._citasPorTipo.entries.map((e) {
              final pct = (e.value / total * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(width: 160, child: Text(e.key, overflow: TextOverflow.ellipsis)),
                    Expanded(child: LinearProgressIndicator(value: e.value / total, backgroundColor: Colors.grey.shade200)),
                    const SizedBox(width: 8),
                    SizedBox(width: 40, child: Text('$pct%', textAlign: TextAlign.right)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildPorSede() {
    if (_citasPorSede.isEmpty) return const SizedBox();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Por sede', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ..._citasPorSede.entries.map((e) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(e.key),
                    Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text('$value', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
