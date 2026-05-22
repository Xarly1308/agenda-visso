import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../utils/app_theme.dart';


class PasoFechaHora extends StatelessWidget {
  final List<DateTime> fechasDisponibles;
  final Map<DateTime, String> fechasNoDisponibles;
  final DateTime? fechaSeleccionada;
  final ValueChanged<DateTime> onFechaSeleccionada;
  
  final List<String> slotsDisponibles;
  final String? horaSeleccionada;
  final ValueChanged<String> onHoraSeleccionada;
  
  final bool cargandoHoras;

  const PasoFechaHora({
    super.key,
    required this.fechasDisponibles,
    required this.fechasNoDisponibles,
    required this.fechaSeleccionada,
    required this.onFechaSeleccionada,
    required this.slotsDisponibles,
    required this.horaSeleccionada,
    required this.onHoraSeleccionada,
    this.cargandoHoras = false,
  });

  String _toAmPm(String hora24) {
    final partes = hora24.split(':');
    final h = int.parse(partes[0]);
    final m = partes[1];
    final periodo = h >= 12 ? 'PM' : 'AM';
    final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '$h12:$m $periodo';
  }

  @override
  Widget build(BuildContext context) {
    final todasFechas = [
      ...fechasDisponibles.map((f) => (fecha: f, disponible: true, motivo: null)),
      ...fechasNoDisponibles.entries.map((e) => (fecha: e.key, disponible: false, motivo: e.value)),
    ]..sort((a, b) => a.fecha.compareTo(b.fecha));

    final ayer = DateTime.now().subtract(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Elige la fecha y hora',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Selecciona un día en el calendario para ver los horarios disponibles.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 32),
        
        Text('Fechas disponibles', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
        const SizedBox(height: 16),
        
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: todasFechas.isEmpty
              ? const Center(child: Text('No hay fechas disponibles'))
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: todasFechas.length,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  itemBuilder: (context, index) {
                    final item = todasFechas[index];
                    final isSelected = item.fecha == fechaSeleccionada;
                    final isPast = item.fecha.isBefore(ayer);
                    final isEnabled = item.disponible && !isPast;
                    
                    return GestureDetector(
                      onTap: isEnabled ? () => onFechaSeleccionada(item.fecha) : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 70,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryContainer : (isEnabled ? AppTheme.surface : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryContainer : (isEnabled ? Colors.grey.shade300 : Colors.grey.shade200),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMM', 'es').format(item.fecha).toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white70 : (isEnabled ? AppTheme.primary : Colors.grey.shade500),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${item.fecha.day}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isSelected ? Colors.white : (isEnabled ? AppTheme.primary : Colors.grey.shade400),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEE', 'es').format(item.fecha),
                              style: TextStyle(
                                fontSize: 12,
                                color: isSelected ? Colors.white70 : (isEnabled ? Colors.grey.shade700 : Colors.grey.shade400),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),

        const SizedBox(height: 32),
        if (fechaSeleccionada != null) ...[
          Text('Horarios disponibles', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary)),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE d \'de\' MMMM', 'es').format(fechaSeleccionada!),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          
          if (cargandoHoras)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
          else if (slotsDisponibles.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(8)),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey),
                  SizedBox(width: 12),
                  Text('No hay horarios disponibles para este día.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: slotsDisponibles.map((hora) {
                final isSelected = hora == horaSeleccionada;
                return ChoiceChip(
                  label: Text(_toAmPm(hora)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) onHoraSeleccionada(hora);
                  },
                  backgroundColor: Colors.white,
                  selectedColor: AppTheme.primaryContainer,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.primaryContainer,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontFamily: 'Hanken Grotesk',
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primaryContainer : Colors.grey.shade300,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                );
              }).toList(),
            ),
        ],
      ],
    );
  }
}
