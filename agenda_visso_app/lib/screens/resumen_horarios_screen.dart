import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/config_provider.dart';
import '../models/sede.dart';
import '../models/horario.dart';
import '../utils/formato_hora.dart';
import 'sede_horarios_screen.dart';

class ResumenHorariosScreen extends StatelessWidget {
  const ResumenHorariosScreen({super.key});

  static const _nombresDias = [
    'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'
  ];

  String _resumenDia(int dia, List<Horario> horarios) {
    final delDia = horarios.where((h) => h.diaSemana == dia).toList();
    if (delDia.isEmpty) return '';
    return '${_nombresDias[dia - 1]} ${delDia.map((h) => '${formato12h(h.horaInicio)}-${formato12h(h.horaFin)}').join(', ')}';
  }

  String _resumenSede(Sede sede, List<Horario> horarios) {
    final deSede = horarios.where((h) => h.sedeId == sede.id).toList();
    if (deSede.isEmpty) return 'Sin horarios configurados';
    final lineas = [1, 2, 3, 4, 5, 6, 7]
        .map((d) => _resumenDia(d, deSede))
        .where((l) => l.isNotEmpty)
        .join('\n');
    return lineas;
  }

  @override
  Widget build(BuildContext context) {
    final config = context.watch<ConfigProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Horarios por sede')),
      body: config.cargando
          ? const Center(child: CircularProgressIndicator())
          : config.sedes.isEmpty
              ? const Center(child: Text('No hay sedes registradas', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: config.sedes.length,
                  itemBuilder: (context, i) {
                    final sede = config.sedes[i];
                    final horariosSede = config.horarios.where((h) => h.sedeId == sede.id).toList();
                    final tieneHorarios = horariosSede.isNotEmpty;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: tieneHorarios ? Colors.indigo.withAlpha(30) : Colors.grey.withAlpha(30),
                          child: Icon(
                            Icons.calendar_month,
                            color: tieneHorarios ? Colors.indigo : Colors.grey,
                          ),
                        ),
                        title: Text(sede.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _resumenSede(sede, config.horarios),
                          style: TextStyle(
                            fontSize: 13,
                            color: tieneHorarios ? Colors.grey.shade700 : Colors.grey,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SedeHorariosScreen(sede: sede)),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
