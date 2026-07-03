import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../utils/colombian_holidays.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;
  final VoidCallback? onDatePickerTap;
  final VoidCallback? onPreviousCita;
  final VoidCallback? onNextCita;
  final bool isDesktop;
  final Set<String> excepcionFechas;
  final Set<String> citaFechas;

  const CalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onDatePickerTap,
    this.onPreviousCita,
    this.onNextCita,
    this.isDesktop = false,
    this.excepcionFechas = const {},
    this.citaFechas = const {},
  });

  DateTime _inicioSemana(DateTime d) =>
      d.subtract(Duration(days: d.weekday - DateTime.monday));

  String _formatDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  @override
  Widget build(BuildContext context) {
    final inicioSemana = _inicioSemana(selectedDate);
    final hoy = DateTime.now();
    const diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Row(
            children: [
              const SizedBox(width: 8),
              Text(
                _mesAnyo(selectedDate),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (onPreviousCita != null || onNextCita != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onPreviousCita != null)
                      isDesktop
                          ? GestureDetector(
                              onTap: onPreviousCita,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.chevronLeft, size: 16, color: Colors.black87),
                                    const SizedBox(width: 6),
                                    const Text('Cita previa',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
                                  ],
                                ),
                              ),
                            )
                          : Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: onPreviousCita,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Icon(LucideIcons.chevronLeft, size: 16),
                                ),
                              ),
                            ),
                    if (onNextCita != null)
                      isDesktop
                          ? GestureDetector(
                              onTap: onNextCita,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text('Cita próxima',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87)),
                                    const SizedBox(width: 6),
                                    const Icon(LucideIcons.chevronRight, size: 16, color: Colors.black87),
                                  ],
                                ),
                            ),
                          )
                        : Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap: onNextCita,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Icon(LucideIcons.chevronRight, size: 16),
                              ),
                            ),
                          ),
                  ],
                ),
              if (onDatePickerTap != null)
                IconButton(
                  icon: const Icon(LucideIcons.calendarDays, size: 18),
                  onPressed: onDatePickerTap,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: () =>
                    onDateSelected(inicioSemana.subtract(const Duration(days: 7))),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (i) {
                    final dia = inicioSemana.add(Duration(days: i));
                    final seleccionado = dia.day == selectedDate.day &&
                        dia.month == selectedDate.month &&
                        dia.year == selectedDate.year;
                    final esHoy = dia.day == hoy.day &&
                        dia.month == hoy.month &&
                        dia.year == hoy.year;
                    final esFestivo = ColombianHolidays.esFestivo(dia);
                    final esExcepcion = excepcionFechas.contains(_formatDate(dia));
                    final esConCita = citaFechas.contains(_formatDate(dia));
                    return _DiaCelda(
                      dia: dia,
                      nombre: diasSemana[i],
                      seleccionado: seleccionado,
                      esHoy: esHoy,
                      esFestivo: esFestivo,
                      esExcepcion: esExcepcion,
                      esConCita: esConCita,
                      onTap: () => onDateSelected(dia),
                    );
                  }),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: () =>
                    onDateSelected(inicioSemana.add(const Duration(days: 7))),
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _mesAnyo(DateTime fecha) {
    const meses = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    return '${meses[fecha.month - 1]} ${fecha.year}';
  }
}

class _DiaCelda extends StatelessWidget {
  final DateTime dia;
  final String nombre;
  final bool seleccionado;
  final bool esHoy;
  final bool esFestivo;
  final bool esExcepcion;
  final bool esConCita;
  final VoidCallback onTap;

  const _DiaCelda({
    required this.dia,
    required this.nombre,
    required this.seleccionado,
    required this.esHoy,
    required this.esFestivo,
    required this.esExcepcion,
    required this.esConCita,
    required this.onTap,
  });

  Color? get _color {
    if (seleccionado) return Colors.white;
    if (esFestivo) return Colors.red;
    if (esExcepcion) return Colors.orange;
    if (esConCita) return const Color(0xFFE65100);
    return null;
  }

  Color _fondo() {
    if (seleccionado) return const Color(0xFF003B74);
    if (esFestivo) return Colors.red.shade50;
    if (esExcepcion) return Colors.orange.shade50;
    if (esConCita) return Colors.orange.shade50;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _fondo(),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(nombre,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
                  color: _color ?? Colors.grey.shade600,
                )),
            const SizedBox(height: 2),
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: esHoy && !seleccionado
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color != null
                          ? _color!.withAlpha(40)
                          : Theme.of(context).colorScheme.primary.withAlpha(20),
                    )
                  : null,
              child: Text('${dia.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: esHoy || seleccionado ? FontWeight.bold : FontWeight.w500,
                    color: seleccionado
                        ? Colors.white
                        : esFestivo
                            ? Colors.red
                            : esExcepcion
                                ? Colors.orange.shade800
                                : esConCita
                                    ? const Color(0xFFE65100)
                                    : esHoy
                                        ? const Color(0xFF003B74)
                                        : Colors.black87,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}
