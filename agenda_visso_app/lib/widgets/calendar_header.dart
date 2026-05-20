import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/colombian_holidays.dart';

class CalendarHeader extends StatelessWidget {
  final DateTime selectedDate;
  final void Function(DateTime) onDateSelected;
  final VoidCallback? onDatePickerTap;
  final Set<String> excepcionFechas;

  const CalendarHeader({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onDatePickerTap,
    this.excepcionFechas = const {},
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
              if (onDatePickerTap != null)
                IconButton(
                  icon: const Icon(Icons.calendar_today, size: 18),
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
                    return _DiaCelda(
                      dia: dia,
                      nombre: diasSemana[i],
                      seleccionado: seleccionado,
                      esHoy: esHoy,
                      esFestivo: esFestivo,
                      esExcepcion: esExcepcion,
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
  final VoidCallback onTap;

  const _DiaCelda({
    required this.dia,
    required this.nombre,
    required this.seleccionado,
    required this.esHoy,
    required this.esFestivo,
    required this.esExcepcion,
    required this.onTap,
  });

  Color? get _color {
    if (seleccionado) return Colors.white;
    if (esFestivo) return Colors.red;
    if (esExcepcion) return Colors.orange;
    return null;
  }

  Color _fondo() {
    if (seleccionado) return const Color(0xFF003B74);
    if (esFestivo) return Colors.red.shade50;
    if (esExcepcion) return Colors.orange.shade50;
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
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
                  fontSize: 11,
                  fontWeight: seleccionado ? FontWeight.w600 : FontWeight.w400,
                  color: _color ?? Colors.grey.shade600,
                )),
            const SizedBox(height: 2),
            Container(
              width: 28,
              height: 28,
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
                    fontSize: 15,
                    fontWeight: esHoy || seleccionado ? FontWeight.bold : FontWeight.w500,
                    color: seleccionado
                        ? Colors.white
                        : esFestivo
                            ? Colors.red
                            : esExcepcion
                                ? Colors.orange.shade800
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
