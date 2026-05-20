import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../providers/config_provider.dart';
import '../utils/formato_hora.dart';

class SedeHorariosScreen extends StatefulWidget {
  final Sede sede;
  const SedeHorariosScreen({super.key, required this.sede});

  @override
  State<SedeHorariosScreen> createState() => _SedeHorariosScreenState();
}

class _SedeHorariosScreenState extends State<SedeHorariosScreen> {
  final Map<int, List<_RangoHorario>> _rangos = {};
  bool _cargando = true;

  static const _nombresDias = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    final config = context.read<ConfigProvider>();
    final horarios = config.getHorariosPorSede(widget.sede.id);
    _rangos.clear();
    for (final horario in horarios) {
      _rangos.putIfAbsent(horario.diaSemana, () => []);
      _rangos[horario.diaSemana]!.add(
        _RangoHorario(inicio: horario.horaInicio, fin: horario.horaFin, id: horario.id),
      );
    }
    _cargando = false;
  }

  Future<void> _guardar() async {
    final config = context.read<ConfigProvider>();
    final horarios = <Horario>[];
    for (final entry in _rangos.entries) {
      for (final r in entry.value) {
        horarios.add(Horario(
          id: r.id,
          profesionalId: '',
          sedeId: widget.sede.id,
          diaSemana: entry.key,
          horaInicio: r.inicio,
          horaFin: r.fin,
        ));
      }
    }
    await config.guardarHorarios(sedeId: widget.sede.id, horarios: horarios);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Horarios guardados')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Horarios - ${widget.sede.nombre}'),
        actions: [
          TextButton(
            onPressed: _cargando ? null : _guardar,
            child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: 7,
              itemBuilder: (context, i) {
                final dia = i + 1;
                final estaActivo = _rangos.containsKey(dia) && _rangos[dia]!.isNotEmpty;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ExpansionTile(
                    leading: Icon(
                      estaActivo ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: estaActivo ? Colors.green : Colors.grey,
                    ),
                    title: Text(_nombresDias[i], style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: estaActivo
                        ? Text(_rangos[dia]!.map((r) => '${formato12h(r.inicio)}-${formato12h(r.fin)}').join(', '))
                        : const Text('No atiende', style: TextStyle(color: Colors.grey)),
                    children: [
                      ...?_rangos[dia]?.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final r = entry.value;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: _TimePickerField(
                                label: 'Inicio',
                                time: r.inicio,
                                onChanged: (v) {
                                  setState(() => _rangos[dia]![idx] = _rangos[dia]![idx].copyWith(inicio: v));
                                },
                              )),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('-'),
                              ),
                              Expanded(child: _TimePickerField(
                                label: 'Fin',
                                time: r.fin,
                                onChanged: (v) {
                                  setState(() => _rangos[dia]![idx] = _rangos[dia]![idx].copyWith(fin: v));
                                },
                              )),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                onPressed: () {
                                  setState(() => _rangos[dia]!.removeAt(idx));
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Agregar rango horario'),
                          onPressed: () {
                            setState(() {
                              _rangos.putIfAbsent(dia, () => []);
                              _rangos[dia]!.add(_RangoHorario(inicio: '08:00', fin: '12:00'));
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _RangoHorario {
  final String id;
  final String inicio;
  final String fin;
  _RangoHorario({this.id = '', required this.inicio, required this.fin});

  _RangoHorario copyWith({String? id, String? inicio, String? fin}) =>
      _RangoHorario(id: id ?? this.id, inicio: inicio ?? this.inicio, fin: fin ?? this.fin);
}

class _TimePickerField extends StatelessWidget {
  final String label;
  final String time;
  final ValueChanged<String> onChanged;

  const _TimePickerField({required this.label, required this.time, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _mostrarSelector(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        child: Text(formato12h(time), textAlign: TextAlign.center),
      ),
    );
  }

  void _mostrarSelector(BuildContext context) {
    final parts = time.split(':');
    var hora24 = int.parse(parts[0]);
    var minutos = int.parse(parts[1]);
    var esPM = hora24 >= 12;
    var hora12 = hora24 == 0 ? 12 : (hora24 > 12 ? hora24 - 12 : hora24);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(label),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _SelectorBoton(
                      label: 'Hora',
                      value: hora12,
                      onIncrement: () => setState(() => hora12 = hora12 == 12 ? 1 : hora12 + 1),
                      onDecrement: () => setState(() => hora12 = hora12 == 1 ? 12 : hora12 - 1),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ),
                    _SelectorBoton(
                      label: 'Min',
                      value: minutos,
                      step: 30,
                      onIncrement: () => setState(() => minutos = minutos >= 30 ? 0 : 30),
                      onDecrement: () => setState(() => minutos = minutos <= 0 ? 30 : 0),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('AM')),
                    ButtonSegment(value: true, label: Text('PM')),
                  ],
                  selected: {esPM},
                  onSelectionChanged: (v) => setState(() => esPM = v.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () {
                  var h = esPM ? (hora12 == 12 ? 12 : hora12 + 12) : (hora12 == 12 ? 0 : hora12);
                  onChanged('${h.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}');
                  Navigator.pop(ctx);
                },
                child: const Text('Aceptar'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SelectorBoton extends StatelessWidget {
  final String label;
  final int value;
  final int step;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const _SelectorBoton({
    required this.label,
    required this.value,
    this.step = 1,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        IconButton.filled(onPressed: onIncrement, icon: const Icon(Icons.keyboard_arrow_up)),
        Text(
          value.toString().padLeft(2, '0'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        IconButton.filled(onPressed: onDecrement, icon: const Icon(Icons.keyboard_arrow_down)),
      ],
    );
  }
}
