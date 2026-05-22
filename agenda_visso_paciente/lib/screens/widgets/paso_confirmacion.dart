import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/sede.dart';
import '../../utils/app_theme.dart';

class PasoConfirmacion extends StatelessWidget {
  final Sede sede;
  final String? profesionalNombre;
  final DateTime fecha;
  final String hora;
  final VoidCallback onNuevaCita;

  const PasoConfirmacion({
    super.key,
    required this.sede,
    required this.profesionalNombre,
    required this.fecha,
    required this.hora,
    required this.onNuevaCita,
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
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle, size: 80, color: Colors.green.shade600),
            ),
            const SizedBox(height: 32),
            Text(
              '¡Cita confirmada!',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(color: AppTheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              'Tu reserva se ha registrado exitosamente. Te enviaremos un recordatorio a tu correo.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 48),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    _buildDetalleFila(Icons.calendar_today, DateFormat('EEEE d \'de\' MMMM \'de\' yyyy', 'es').format(fecha)),
                    const Divider(height: 32),
                    _buildDetalleFila(Icons.access_time, _toAmPm(hora)),
                    const Divider(height: 32),
                    _buildDetalleFila(Icons.location_on, '${sede.nombre}\n${sede.direccion}'),
                    if (profesionalNombre != null) ...[
                      const Divider(height: 32),
                      _buildDetalleFila(Icons.medical_services, 'Dr(a). $profesionalNombre'),
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            OutlinedButton.icon(
              onPressed: onNuevaCita,
              icon: const Icon(Icons.add),
              label: const Text('Agendar otra cita'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetalleFila(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppTheme.primaryContainer, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: AppTheme.primary),
          ),
        ),
      ],
    );
  }
}
