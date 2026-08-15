import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
      final pacientesMes = pacientes.where((p) {
        return p.creadoEn.isAfter(inicio.subtract(const Duration(days: 1))) &&
               p.creadoEn.isBefore(fin.add(const Duration(days: 1)));
      }).toList();
      _nuevos = pacientesMes.where((p) => !p.yaEraPaciente).length;
      _antiguos = pacientesMes.where((p) => p.yaEraPaciente).length;

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
    if (kIsWeb) {
      return _buildWebLayout();
    }
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

  Widget _buildWebLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Estadísticas', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const Spacer(),
              _buildMesSelectorCompact(),
            ],
          ),
          const SizedBox(height: 24),
          if (_cargando)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildKPIRow(),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildPorTipo()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildPorSede()),
                    ],
                  );
                }
                return Column(
                  children: [
                    _buildPorTipo(),
                    const SizedBox(height: 16),
                    _buildPorSede(),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKPIRow() {
    final totalPacientes = _nuevos + _antiguos;
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 4 : (constraints.maxWidth > 400 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.0,
          children: [
            _buildKPICard('Total Citas', '$_totalCitas', Icons.calendar_month, Colors.blue),
            _buildKPICard('Pacientes', '$totalPacientes', Icons.people, Colors.purple),
            _buildKPICard('Nuevos', '$_nuevos', Icons.person_add, Colors.green),
            _buildKPICard('Antiguos', '$_antiguos', Icons.history, Colors.orange),
          ],
        );
      },
    );
  }

  Widget _buildKPICard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMesSelectorCompact() {
    final meses = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left, size: 20),
          onPressed: () {
            setState(() {
              if (_mesSeleccionado == 1) { _mesSeleccionado = 12; _anioSeleccionado--; }
              else { _mesSeleccionado--; }
            });
            _cargar();
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('${meses[_mesSeleccionado - 1]} $_anioSeleccionado',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: 20),
          onPressed: () {
            setState(() {
              if (_mesSeleccionado == 12) { _mesSeleccionado = 1; _anioSeleccionado++; }
              else { _mesSeleccionado++; }
            });
            _cargar();
          },
        ),
      ],
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
              child: Text('$_totalCitas', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
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
